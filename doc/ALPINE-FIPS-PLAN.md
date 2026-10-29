# Alpine migration and FIPS research

## Experimental Alpine build
- `Dockerfile.alpine` uses `alpine:edge` **rolling**, with edge/main and edge/community as the distro repositories. OpenSSH 10.6_p1-r1 was listed for edge on 2026-10-29. Packages are not pinned and can change between builds.
- Includes Bash deliberately to preserve the existing Bash entrypoint. Alpine package and process conventions still differ from Debian: rsyslog configuration, `fail2ban` filters/actions distribution, package file paths, `shadow` user tools and firewall backend must be verified.
- The base image is mutable: a container's startup `apk upgrade --available` applies published package changes to its writable layer before sshd starts; it does **not** continuously update or replace a running sshd. Restarting the *same* container repeats the upgrade; recreating from an old image starts from that image again. Maintain a previous known-good image for rollback. Do not mix stable and edge repositories.\n- Build only in a disposable environment: `docker build -f Dockerfile.alpine -t sftp-private:alpine-test .`
- Start with a **new** empty test `/config`, explicit credentials and a nonproduction host port. Never mount production host keys, credentials, or SFTP data into this experiment.
- Run `bash -n /usr/local/bin/entrypoint.sh`, `/usr/local/bin/validate-security.sh`, `/usr/local/bin/security-status.sh` and `/usr/local/bin/healthcheck.sh`.
- Independently test login success/failure, shell denial, file transfers, user chroots, host-key persistence, rsyslog collection, the three SSH-related Fail2Ban filters, ban/unban, IPv6, firewall network mode, container restart and rollback.
- The health check confirms the daemon and SSHD syntax, **not** enforcement of firewall bans or FIPS compliance.
- Do not assume the shared entrypoint works unmodified on Alpine. This is a packaging feasibility experiment, not production acceptance.

## CVE and update policy
- `AUTO_UPDATE=suite` applies the configured distribution's available package upgrades at startup and reports command failure. It **cannot** pull unavailable upstream OpenSSH versions and does not replace image rebuilds.
- `scripts/security-status.sh` inventories package versions and links to OpenSSH, Debian and Alpine advisories. It does **not** compute CVE impact or silently claim vulnerabilities fixed.
- A later CI job should fetch vendor advisories, correlate them with package fixes and generate a human-reviewed report with affected/mitigated/unknown/fixed states. Provenance, SBOM and image rebuild should be separate from runtime update.
- Changes to sshd or its libraries at runtime may require a deliberate service restart; do not advertise active patching of an already running daemon.

## Optional FIPS profile — design only
- No FIPS profile is implemented or certified in this pass.
- A crypto allowlist alone is not FIPS 140-3 validation. Identify the validated provider and operating environment first; confirm system crypto policy and all SSH KEX/ciphers/MACs/keys allowed.
- Keep FIPS testing isolated from the normal FileZilla-compatible password-only SFTP default. Ed25519/Curve25519/ChaCha20 compatibility requires review.
- Do not describe the resulting container as CISA-certified. Map hardening evidence to relevant CISA recommendations and accepted benchmarks instead.

## Deployment cautions
- In `entrypoint.sh`, `DEFAULT_ADMIN` now defaults to false, and true requires a non-placeholder `ADMIN_PASS`. Existing `/config/sshd/users.conf` is not automatically replaced.
- Passwords in environment variables can be exposed via container metadata; favor a mounted, access-controlled users file and eventually secret-file support.
- Existing production image and config are not changed by GitHub commits.
