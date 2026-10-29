# Change Log — sftp-private

Changes to this private repository are recorded here, including documentation-only changes. Dates are UTC unless otherwise stated.

## 2026-10-29 — Initial documentation and baseline security review
**Purpose:** establish review history and track the first examination of SSHD, Fail2Ban, Docker, dependency updating and security targets.

**Added files:**
- `doc/README.md` — documentation index and development/release rules.
- `doc/CHANGELOG.md` — change tracking and code review record.
- `doc/SECURITY-REVIEW.md` — initial risks, CVE applicability and proposed testing.

**Runtime code/config changes:** none.
**Validation:** source inspection of the uploaded `sftp-private-main.zip` and GitHub repository structure; no Docker build, live exploit testing or production verification performed.
**Status:** documentation baseline only. Findings remain to be tested before code changes or a public release.


## 2026-10-29 — Production configuration evidence and CVE review refinement
**Purpose:** preserve reported real-world firewall-ban effectiveness and distinguish production settings from repository defaults.

**Modified files:**
- `doc/SECURITY-REVIEW.md` — production SSHD/Fail2Ban baseline, Unraid blocklist history, configuration-specific CVE assessment and test plan.
- `doc/CHANGELOG.md` — this entry.

**Runtime code/config changes:** none.
**Validation:** production snippets supplied by operator, public OpenSSH/Debian advisory review; **not** a live container inspection or repeat of operator's ban tests.
**Status:** documentation-only; proposed hardening awaits review and controlled testing.

## 2026-10-29 — SSHD baseline hardening and security preflight
**Purpose:** establish safer, testable defaults while preserving password-based SFTP and proven firewall ban actions.

**Modified:**
- `defaults/sshd/sshd_config` — bound `LoginGraceTime` to 20s; set `MaxAuthTries 3`, `MaxSessions 1`, `MaxStartups 10:30:30`; explicitly disable PAM, keyboard-interactive/public-key authentication, TTY and user environment; configure internal-sftp AUTHPRIV INFO logging. Password authentication remains enabled; existing user restriction and crypto choice are not rewritten.
- `Dockerfile` — install the read-only security validation script in the image.
- `doc/CHANGELOG.md` — this change record.
- `doc/SECURITY-REVIEW.md` — test coverage and rollout cautions.
**Added:**
- `scripts/validate-security.sh` — validate sshd syntax/effective settings and report Fail2Ban configuration/daemon readiness without modifying runtime.

**Unchanged:** `entrypoint.sh`, `update-inplace.sh`, Fail2Ban filters/actions and jail defaults, production `/config` files, public repo.
**Testing:** static source checks only; no Docker build or connected Proxmox instance available. Run `bash -n /usr/local/bin/validate-security.sh` and `bash /usr/local/bin/validate-security.sh` inside a rebuilt private image. Script validates a specific password-only profile, not every optional deployment profile. It warns (does not fail) when Fail2Ban is unavailable, because this pass focuses on SSHD configuration.
**Deployment/rollback:** defaults are seeded only when `/config/sshd/sshd_config` is absent; existing persistent configs remain unchanged. Backup live config, compare, validate offline, then deploy explicitly. Revert these commits to restore old defaults; restart from last tested image if needed.
**Status:** private development only, not yet integration-tested or ready for public release.

## 2026-10-29 — Harden first boot, fix distro updates, and prototype Alpine
**Modified:** `entrypoint.sh` (disable default admin/password; require explicit non-placeholder password when opted in; tighten users.conf permissions); `update-inplace.sh` (fail on update errors; apt upgrade or apk upgrade within configured distro); `Dockerfile` (stronger health check and utility scripts); `doc/CHANGELOG.md` (this record).
**Added:** `Dockerfile.alpine` (experimental Alpine 3.23 Bash-enabled image); `scripts/healthcheck.sh` (SSHD/Fail2Ban daemon health); `scripts/security-status.sh` (package version inventory and advisory URLs); `doc/ALPINE-FIPS-PLAN.md` (test plan, FIPS scope and limitations).
**Not changed:** production deployment, public repository, Fail2Ban firewall rules and cipher lists.
**Risk and limitations:** first-boot behavior intentionally changes; set up real user credentials before starting a fresh container. Existing persisted configs are retained. Alpine path is **unbuilt and untested** and may need compatibility fixes. Health checks do not prove firewall enforcement; version reporting does not classify CVEs; FIPS remains research-only.
**Validation:** repository source edits only; no running container, Docker build, functional packet drop, or FIPS validation performed.
**Rollback:** restore prior private Git commits and redeploy last validated image; back up /config before testing. Never test Alpine against production bind mounts.
**Status:** experimental; code review and integration tests required before production rollout.

## 2026-10-29 — Fail2Ban startup gate
**Modified:** `entrypoint.sh`, `doc/CHANGELOG.md`.
**Behavior:** after attempting Fail2Ban start, poll daemon and `sshd` jail readiness (10 one-second retries) before starting sshd. Default `F2B_REQUIRED=true` refuses to start SFTP if jail is unavailable; `F2B_REQUIRED=false` permits isolated debugging.
**Known limits:** a responding jail does not prove iptables/nftables packet enforcement; that requires integration testing. In production test with an alternate port and known-good fallback before deploying. No live build or runtime tests performed.
**Status:** private experimental change, not yet production-validated.

## 2026-10-29 — Select Alpine edge for rolling OpenSSH packages
**Modified:** `Dockerfile.alpine`, `doc/ALPINE-FIPS-PLAN.md`, `doc/CHANGELOG.md`.
**Behavior:** Alpine build now starts with `alpine:edge` and refreshes/upgrades APK packages before installing SFTP dependencies. Runtime `AUTO_UPDATE=suite` already selects `apk update` and `apk upgrade --available` for Alpine.
**Reason:** as checked 2026-10-29, Alpine edge main packages OpenSSH `10.6_p1-r1`; this cannot guarantee future security fixes are released immediately.
**Testing:** repository edit only; Docker build and startup, WHOIS availability, Fail2Ban enforcement, SFTP login and rollback remain unverified.
**Caution:** rolling packages can introduce regressions; upgrades only become effective for SSHD when the daemon is (re)started. Existing /config state must be backed up. No changes to production or public repository.
**Status:** experimental development.

## 2026-10-29 — User UID/GID parsing and private production Compose review
**Modified:** `entrypoint.sh`, `defaults/sshd/users.conf`, `examples/docker-compose.yml`, `doc/CHANGELOG.md`.
**Behavior:** support `user:password:uid:gid[:dirs]` and `user:encrypted_password:e:uid:gid[:dirs]` consistently; opt-in first-boot admin supports `ADMIN_USER`, `ADMIN_PASS`, `ADMIN_UID`, `ADMIN_GID`. Reject malformed account specifications without printing passwords. Removed checked-in `admin:password` from packaged default. Do not recursively chown existing populated/mounted user data directories.
**Compose:** experimental Alpine edge example uses isolated test config and port 2222, retains NET_ADMIN/NET_RAW for testing firewall actions, and does not disable seccomp/AppArmor. Private Proxmox paths, IPs, and real credentials are not added.
**Compatibility:** existing persistent `/config/sshd/users.conf` remains in effect. `PUID=0` and `PGID=0` are not currently used to assign the SFTP account UID/GID. If an existing Unix user has the wrong numeric UID/GID, the entrypoint does not automatically migrate it. Existing mapped files may need host permission/ACL changes; do not recursively chown host storage.
**Validation:** source review and GitHub commit only; Alpine build, live SFTP transfer and ban integration testing NOT performed.
**Rollback:** revert private repo commits; back up /config and run on isolated test mounts.
**Status:** requires test before public/production use.

## 2026-10-29 — Consolidate default Fail2Ban jails and add diagnostics
**Modified:** `defaults/fail2ban/jail.local`, `defaults/fail2ban/jail.d/00-sshd.local`, `defaults/fail2ban/jail.d/10-sshd-extras.local`, `doc/CHANGELOG.md`.
**Added:** `scripts/audit-fail2ban.sh` (read-only runtime jail, regex and firewall inspection).
**Behavior:** SSHD, cipher mismatch, banner failure and recidive have single bundled definitions in jail.local. Default IP exemption only localhost, with explicit allports recidive action and no email. Existing WHOIS action retained. No default LAN trust networks added. Fail2Ban .local files under jail.d load *after* jail.local, so the old overrides are comment-only for new deployments.
**Critical migration:** this does not update already-populated `/config/fail2ban` files. The operator's production `jail.d/jail.local`, `00-sshd.local`, and extras still override root `jail.local`; back up and consolidate them separately before deploying. Runtime DNS/WHOIS and ban timing may change if migrated.
**Validation:** static code review only; **not** validated using Fail2Ban binary or live packet enforcement. Run `fail2ban-client -t` and audit on a disposable container; verify ban/unban, recidive, action expansion and restart persistence before production. An extra jail action may have distribution-specific requirements.
**Status:** private experimental, not production-validated.

## 2026-10-29 — Runtime chroot/share ownership enforcement
**Modified:** `entrypoint.sh`, `doc/CHANGELOG.md`.
**Behavior:** apply root:root 0755 to each /home/USER chroot; create missing requested directories and assign SFTP account numeric UID/GID with mode 2770. Inspect pre-existing first-level directories (including mounted shares), preserving their permissions by default. Optional `SHARE_MOUNT_PERMS=group` applies nonrecursive chown and chmod 2770 to those directories; this can change the host bind-mount root, so must be explicitly requested after backup. Never recursively change host data. Reject share paths containing slash/traversal and symlink share roots. Corrected an earlier malformed literal backslash-n shell block.
**Compatibility:** Existing nobody:users (often 65534:100) directories with mode 777 continue to work when left untouched; future tighter group modes require checking SFTP user's GID 100 and host ACLs. PUID/PGID are not used for file-user identity.
**Testing:** source edit only; no Alpine build, `bash -n`, real mount permission test or FileZilla transfer has been performed. Check in isolated test before prod. Do not enable opt-in ownership mode on /VMs until impact reviewed.
**Status:** private untested.

## 2026-10-29 — Authoritative users.conf lifecycle
**Modified:** `entrypoint.sh`, `doc/CHANGELOG.md`. **Added:** `doc/USER-MANAGEMENT.md`.
**Behavior:** on startup, create missing users, reapply password/hash for existing users, reject UID/GID drift, preserve chroot and existing mount permissions. Missing users.conf can seed an admin account only with explicitly provided non-placeholder ADMIN_PASS; `DEFAULT_ADMIN` defaults true but this now refuses to start when missing config and missing password. Existing file wins over env settings; password changes require restart. No default admin/admin credentials committed.
**Limitations:** removing users from config does not automatically delete users, preexisting custom SSHD AllowUsers may exclude new users, env credentials are observable to Docker administrators. Build/integration tests not run; existing production untouched.
**Status:** experimental private repository; test before public release.

## 2026-10-29 — Reconcile default Docker build with Alpine edge
**Modified:** `Dockerfile`, `entrypoint.sh`, `doc/CHANGELOG.md`.
**Added:** `Dockerfile.debian` (retains previous Debian alternative, with malformed escaped Dockerfile lines normalized).
**Default build:** `Dockerfile` now uses `FROM alpine:edge`, installs Bash, OpenSSH server/client/SFTP, Fail2Ban, rsyslog, WHOIS, iptables/nftables and prerequisites through APK. Runs `apk upgrade --available` at build; startup updater can repeat at container boot. Uses Alpine tini path, existing healthcheck, and diagnostic scripts.
**Entrypoint fixes:** Alpine version reporting, Alpine nologin path, avoid recursive permissions/ownership rewriting within persistent /config, prevent copying jail.local again into jail.d/jail.local, reject empty user list at startup. User creation, password rotation, host keys and existing mounts retain previous intended semantics.
**Limitations and outstanding issues:** Existing /config is never automatically migrated; old Fail2Ban jail.d overrides may remain. No automatic CVE verdict, running-daemon hot-patching, FIPS validation, or scheduled in-process update. Build and live network/firewall/FileZilla testing have not been performed. New DEFAULT_ADMIN requires explicit ADMIN_PASS on first boot, not admin/admin. No production or public repo changes.
**Validation:** static file review only. No Docker daemon available in assistant runtime; check `docker build --pull -t sftp-private:edge-test .` and test isolated port/config.
**Rollback:** use last known-good deployed image and backed-up /config; older Debian path: `docker build -f Dockerfile.debian .`.
**Status:** private development / pending integration tests.

## Required format for future entries
- Date/time (UTC), author/agent, purpose and issue/PR
- Added/modified/deleted paths, with exact behavior differences
- Security impact, migration/rollback information
- Commands/tests and observed results
- Review outcome and whether released publicly
