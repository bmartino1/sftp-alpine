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

## Required format for future entries
- Date/time (UTC), author/agent, purpose and issue/PR
- Added/modified/deleted paths, with exact behavior differences
- Security impact, migration/rollback information
- Commands/tests and observed results
- Review outcome and whether released publicly
