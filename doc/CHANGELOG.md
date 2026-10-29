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

## Required format for future entries
- Date/time (UTC), author/agent, purpose and issue/PR
- Added/modified/deleted paths, with exact behavior differences
- Security impact, migration/rollback information
- Commands/tests and observed results
- Review outcome and whether released publicly
