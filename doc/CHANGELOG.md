## 2026-10-29 — SSH forwarding enforcement verified; private deployment guidance
Windows client authenticated via SSH port 2222; server denied PTY, terminated shell with SFTP-only message and refused a TCP-forwarded channel with `administratively prohibited`. A localhost listener on Windows was reachable, but forwarded SSH key exchange failed; therefore client-side listener establishment is not a server forwarding bypass. Container effective settings include `DisableForwarding yes`, `AllowTcpForwarding no`, `PermitTunnel no`, `X11Forwarding no`, `ForceCommand internal-sftp`; all four Fail2Ban jails and FileZilla transfers were confirmed operational on fresh Alpine/OpenSSL build. Remaining explicit negative tests: X11 forwarding, SSH tunnel devices, interrupted SFTP transfer resume and key persistence across recreation.
The user requested a generic `admin:admin` account for distribution; do not ship an active known default password. Keep credential-free example, require explicit secrets on deployment.

## 2026-10-29 — Defense-in-depth SFTP forwarding restriction
**Modified:** default sshd configuration and security audit. Windows OpenSSH shell test authenticated and reported `PTY allocation request failed on channel 0`; this confirms denied PTY allocation, not independently denial of all forwarded TCP channels. Existing settings denied TCP, agent, X11 and tunnels, while effective `DisableForwarding` remained `no`. Set `DisableForwarding yes` explicitly and check it in `validate-security.sh`. Test `ssh -N -L ... -o ExitOnForwardFailure=yes` with an attempted connection through the forward; local listener establishment alone is not proof that the server accepted a forwarding channel. Runtime re-test pending; persisted sshd configs must be updated separately.

## 2026-10-29 — Fix false negative SSHD security audit on Alpine OpenSSH 10.6
**Modified:** `scripts/validate-security.sh` and changelog. Fresh config Alpine runtime was healthy, `sshd -t` passed, and FileZilla authenticated and uploaded four files with restricted cryptographic algorithms, but the audit emitted 13 false failures because `sshd -T` option names are mixed case and the awk lookup was case sensitive. Match SSHD option names case insensitively. Runtime revalidation pending, with no SSHD configuration or firewall changes in this fix.

## 2026-10-29 — Private Tailscale home-lab deployment and testing scope
**Modified:** `README.md`, `doc/CHANGELOG.md`.
**Target:** private Docker Hub Alpine image for authorized friends using FileZilla, NAS and Docker SFTP clients over Tailscale. Hardened security controls guided by CISA/FIPS principles, without FIPS or CISA certification claims.
**Observed live tests:** Proxmox Debian 13 LXC bridge-published port 2222, FileZilla upload, matching host/container SHA-256 checksums, four Fail2Ban jails, actual SSH client IP detection, automated client ban preventing valid-auth SSH/SFTP connection, manual unban and healthy container.
**Outstanding:** rebuild latest image to add OpenSSL CLI and test hardened SSH algorithms, new isolated config host-key provisioning, tailnet NAT/source-IP behavior, additional isolation and lifecycle tests; no published Docker Hub image yet.

## 2026-10-29 — OpenSSL diagnostics and explicit SSH algorithm profile
**Modified:** `Dockerfile`, `defaults/sshd/sshd_config`, `doc/CHANGELOG.md`.
**Observed:** Alpine edge OpenSSH 10.6p1 uses OpenSSL 3.5.9 libraries but `openssl` CLI is missing. SSHD effective defaults include SHA-1 MACs, CTR ciphers and more algorithms than the target hardened policy.
**Changes:** Install Alpine `openssl` CLI and assert presence at build. New default SSHD profile prefers ML-KEM/SNTRUP hybrid key exchange and allows Curve25519 and ECDH P-256 fallback; limits ciphers to ChaCha20-Poly1305 / AES-GCM and MACs to SHA-2 encrypt-then-MAC; restricts server host-key algorithms to ED25519 / RSA SHA-2. Existing first-boot ED25519 and RSA-4096 host keys are preserved, not regenerated.
**Migration and risks:** Existing persisted `/config/sshd/sshd_config` is never overwritten; new algorithm defaults will not apply until explicitly reviewed/merged into persisted config. This is not a FIPS build, FIPS-approved algorithm list, or FIPS certification. Validate with `sshd -t`, `sshd -T`, and FileZilla before release. Runtime not yet retested after commit.

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

## 2026-10-29 — Alpine migration README and license audit
**Modified:** `README.md`, `Dockerfile`, `doc/README.md`, `doc/CHANGELOG.md`.
**Added:** `doc/THIRD-PARTY-LICENSES.md`.
**License decision:** preserved the existing MIT root LICENSE unchanged; third-party Alpine packages have independent licenses (edge/community WHOIS GPL-2.0-or-later). Inventory/redistribution obligations need review before public image release.
**Documentation:** removed obsolete Debian 12/Ubuntu assumptions, inaccurate default-password claims, stale phusion/baseimage description and broken legacy examples; explained Alpine edge, WHOIS, users.conf, mounted shares, Fail2Ban, rolling updates, FIPS limits, private development, and verification.
**Build:** check that `whois`, `sshd` and `fail2ban-client` executables exist at image build time, failing immediately if not installed.
**Validation:** package metadata checked against Alpine's published index, source changes committed; container build, runtime, security functions and third-party notices inside a published image are **not tested**.
**Deployment:** public repository and production image unchanged; no credentials added.
**Status:** development review pending.

## 2026-10-29 — Alpine version provenance and opt-in periodic package upgrades
**Added:** `scripts/report-versions.sh` (build/pre-update/post-update/periodic package version inventory), `scripts/periodic-update.sh` (opt-in unattended APK upgrades and restart-required notice).
**Modified:** `Dockerfile` (include scripts; build version stamp via report-versions), `entrypoint.sh` (log versions before and after startup updates; optionally run periodic updater), `doc/CHANGELOG.md`.
**Settings:** `AUTO_UPDATE=suite` still upgrades at startup. `AUTO_UPDATE_INTERVAL_HOURS=0` (default) disables unattended updates. Positive integer enables background `apk update && apk upgrade --available` on that hourly cadence. `/config/debug/restart-required.txt` records detected OpenSSH package changes; logs mark RESTART REQUIRED. Does not automatically restart sshd or guarantee security fixes are active in running processes.
**Security and deployment risks:** periodic package replacements can break a live rolling-release container. Use on a disposable Alpine environment first; enable only with planned service restarts and rollback. Current script tracks OpenSSH package changes explicitly but other upgraded libraries/services can also require restart. Persisted /config must be backed up and production volumes never used for experimental testing.
**Validation:** source inspection only; no live Alpine Docker build, end-to-end SFTP, Fail2Ban packet enforcement or periodic restart testing completed.
**Status:** private development; not production validated.

## 2026-10-29 — Final Alpine readiness source audit
**Modified:** `entrypoint.sh`, `doc/CHANGELOG.md`. **Added:** `doc/ALPINE-READINESS-AUDIT.md`.
**Fix:** removed two malformed literal escaped-newline sequences in entrypoint that affected password handling and empty-user failure.
**Audit scope:** Alpine package readiness, first boot and /config seeding, user/password synchronization, UID/GID/chroot/mount permissions, SSHD hardening, Fail2Ban actions/filters, WHOIS, runtime upgrades and FIPS boundaries.
**Incomplete items:** no Docker build or `bash -n` executed; current SFTP_USERS and CLI additions can conflict with users.conf; removing users is not automatically enforced; no file watcher; existing Fail2Ban overrides persist; actual firewall drop and WHOIS need runtime tests. Startup updater still continues on failure.
**Security:** no live secrets added; no public or production modifications.
**Status:** static review complete, integration tests pending; private experimental release only.

## 2026-10-29 — Alpine runtime: SSHD jail backend failure
**Modified:** `defaults/fail2ban/jail.local`, `doc/CHANGELOG.md`.
**Observed:** first successful Alpine edge Docker build installed Fail2Ban 1.1.1, OpenSSH 10.6p1 and WHOIS. In isolated LXC test, Fail2Ban failed before SSHD startup: `Backend 'systemd' failed to initialize due to No module named 'systemd'`. Fail2Ban's effective config had `['add', 'sshd', 'systemd']` despite global `[DEFAULT] backend = polling`.
**Fix:** explicitly set `backend = polling` in bundled `[sshd]` jail to override the packaged SSHD-specific systemd default and use `/config/log/auth.log`.
**Migration:** existing persisted `/config/fail2ban/jail.local` is intentionally not overwritten on restart. Test installations must update that persisted file separately (or recreate only disposable test config).
**Follow-up:** check rsyslog imkmsg /dev/kmsg warning, verify actual jail initialization, all firewall actions and auth log routing. No production changes.

## 2026-10-29 — Explicit polling for all four Alpine Fail2Ban jails
**Modified:** `defaults/fail2ban/jail.local`, `defaults/fail2ban/jail.d/00-sshd.local`, `defaults/fail2ban/jail.d/10-sshd-extras.local`, `doc/CHANGELOG.md`.
**Reason:** Alpine's packaged SSHD jail selected systemd despite the global default; first integration test failed without python systemd. Explicit `backend = polling` now appears in `[sshd]`, `[sshd-cipher-mismatch]`, `[sshd-banner-fail]` and `[recidive]`. Removed literal escaped newline artifacts in two retired jail fragments.
**Critical migration:** Existing `/config/fail2ban/jail.local` and `jail.d` are not overwritten. Existing test configurations must be individually patched or separately reset; user secrets and SSH host keys must be preserved.
**Validation:** previously captured Fail2Ban dry-run showed sshd was systemd and the other three were polling. New all-jail overrides are committed, but rebuild, full startup and firewall enforcement remain unverified. Keep SSHD fail closed.

## 2026-10-29 — Alpine OpenSSH UsePAM incompatibility discovered in live LXC
**Modified:** `defaults/sshd/sshd_config`, `entrypoint.sh`, `doc/CHANGELOG.md`.
**Observed:** Alpine edge OpenSSH 10.6p1 logs `Unsupported option UsePAM` at line 52. Editing bind-mounted `/config/sshd/sshd_config` did not fix the running `/etc/ssh/sshd_config`, because earlier entrypoint sed -i runtime modifications replace the original symlink with a separate config file.
**Fix:** omit `UsePAM no` from Alpine default and remove that unsupported directive from the active runtime `/etc/ssh/sshd_config` during startup on Alpine, even when old persisted configs still contain it. Do not rewrite the persisted config automatically.
**Security and further work:** no PAM is enabled on Alpine. Validate `sshd -t` and actual password/SFTP session after rebuild. Four Fail2Ban jails start with polling, but empty iptables/nft rules before first ban do not establish whether actions can enforce; test manual ban, packet blocking, and startup security gates. Investigate whether all /etc config writes should be explicitly staged to avoid broken symlinks.
**Validation:** source change only, not yet rebuilt in test LXC.

## Required format for future entries
- Date/time (UTC), author/agent, purpose and issue/PR
- Added/modified/deleted paths, with exact behavior differences
- Security impact, migration/rollback information
- Commands/tests and observed results
- Review outcome and whether released publicly
