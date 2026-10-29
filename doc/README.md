# SFTP Private — Engineering Documentation

Private development and review workspace for the public `bmartino1/sftp2` project.

## Change control
- All edits must be recorded in [CHANGELOG.md](CHANGELOG.md) with date, purpose, changed paths, validation, and release status.
- Every code change must be listed in the associated chat response and reviewed before public release.
- Keep the public `sftp2` repository untouched until an explicit publication decision.
- Never commit live credentials, user passwords, private SSH keys, UniFi tokens, internal firewall secrets, or customer-specific configurations.
- Document source findings separately from verified test results; do not claim compliance or certification without evidence.

## Documents
- [CHANGELOG.md](CHANGELOG.md) — chronological audit of edits
- [SECURITY-REVIEW.md](SECURITY-REVIEW.md) — initial architecture, risks, test plan and references

## Development workflow
1. Capture baseline and reproduce.
2. Prepare changes on a review branch.
3. Run syntax, integration, negative security and rollback tests.
4. Review changes and merge into private main only when accepted.
5. Publish selected, sanitized changes to the public repo separately.
