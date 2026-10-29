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

## Required format for future entries
- Date/time (UTC), author/agent, purpose and issue/PR
- Added/modified/deleted paths, with exact behavior differences
- Security impact, migration/rollback information
- Commands/tests and observed results
- Review outcome and whether released publicly
