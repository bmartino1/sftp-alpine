# Initial SFTP / SSHD / Fail2Ban Security Review

**Date:** 2026-10-29
**Target:** `bmartino1/sftp-private` (Debian Trixie based SFTP container)
**Scope:** static source review only; no runtime or network assertions.

## Intended product boundaries
- OpenSSH as an **SFTP-only** endpoint; never enable interactive shell or SSH forwarding for file users.
- Map explicitly authorized volumes under per-user homes with strict chroot ownership.
- Detect SSH abuse, ban only confirmed offending addresses, and preserve evidence.
- Keep packages updated, verify status and fail clearly; use rebuilt, signed images for durable deployment.
- Support optional UniFi integration without bundling production credentials.
- Treat honeypot telemetry as a separate, isolated design decision from real file-sharing service.

## Priority findings for testing

| Priority | File(s) | Finding / required verification |
| --- | --- | --- |
| Critical | `defaults/sshd/sshd_config` | `LoginGraceTime 0` means no authentication grace timeout; DoS exposure. Evaluate bounded value alongside `MaxStartups` and `PerSourcePenalties`; do not blindly assume 0 fixes a CVE. |
| High | `entrypoint.sh` | `fail2ban-client -x start || warn` may leave SFTP accessible with no working ban protection. Establish fail-closed/explicit degraded-mode policy. |
| High | `defaults/fail2ban/jail.local`, `examples/docker-compose.yml` | iptables/nftables actions inside a container with `NET_ADMIN`/`NET_RAW` are topology-dependent. Prove packets are dropped with bridge, host, macvlan/ipvlan and real client IP visibility. |
| High | `update-inplace.sh` | `|| true` hides apt failures, `--only-upgrade` targets only five named packages, and the script exits 0. Separate rebuild/update scan, report statuses and test rollback. |
| High | `defaults/sshd/users.conf`, `entrypoint.sh` | A checked-in `admin:password` example deserves removal/safer seeding. Prove it cannot become an active public credential. |
| Medium | `defaults/sshd/sshd_config` | Password auth is not disabled by default. Select explicit authentication profile and test no shell, no forwarding, chroot and authorized-keys behavior. |
| Medium | `defaults/fail2ban/action.d/logwhois.conf` | WHOIS lookup executes as a ban action; network delays may interfere with ban processing. Make enrichment asynchronous / bounded and never gate enforcement on WHOIS. |
| Medium | `Dockerfile` | Unpinned `debian:trixie-slim`, package provenance, signed SBOM, image scanning and reproducibility require a supply-chain design. |
| Medium | `defaults/fail2ban/filter.d/*` | Test filters against real sshd logs, crafted input, IPv4/IPv6, timezones and spoofed log strings; avoid false bans. |
| Medium | `entrypoint.sh`, `/config` | Persistent SSH host keys, user secrets, file modes, chroot mount permissions and symlink/overlay modes need negative tests. |

## CVE triage (not proof of image security)
- **CVE-2025-26465:** `ssh` *client* host impersonation under `VerifyHostKeyDNS`; applicable client feature was disabled by default. Do not characterize this as an `sshd` SFTP-server vulnerability.
- **CVE-2025-26466:** `sshd` preauthentication DoS through PING packets in upstream OpenSSH 9.5p1–9.9p1. Compare actual Debian package security status, not upstream version numbers alone.
- Check OpenSSH release advisories and Debian's security tracker for *every* package release, including 10.6; upstream release does not imply Debian Trixie ships it.
- Test host/container kernel boundary, iptables/nftables behavior, and resource limits as part of CVE defense-in-depth.

## FIPS and security framework distinctions
- A FIPS 140-3 validated cryptographic module is a **specific module/version/operational environment** claim, not merely a set of SSH cipher names.
- A FIPS-oriented SSH profile may require validated crypto providers, approved algorithms, key management, entropy and documented operational-mode verification.
- Docker Hardened Images (DHI) offers smaller images, supply-chain artifacts, and paid FIPS/STIG variants; adopting a DHI base does **not** certify an arbitrary derivative container.
- CISA publishes guidance such as Secure by Design and KEV; there is no generic 'CISA-certified Docker container' label to assume.
- Ed25519 and Curve25519 defaults are not automatically suitable for a FIPS-only profile; confirm requirements against the specific validated module.
- Keep general hardened SFTP and optional FIPS-targeted builds as separate test profiles until proven compatible.

## Proposed staged work (not yet implemented)
1. Preserve baseline, collect `sshd -T`, `sshd -t`, `fail2ban-client -d`, network mode, effective firewall state, package candidates and SBOM.
2. Test SFTP-only confinement, authentication, chroot permissions, mapped volumes and non-SFTP request denial.
3. Prove Fail2Ban end-to-end on each supported network mode; consider host-firewall or UniFi API integration only through carefully scoped permissions.
4. Replace masked updater failures with explicit health reporting, routine image rebuilds, CVE scanning and rollback.
5. Add separate hardened/FIPS-research image tracks; record exact controls, prerequisites and limits.
6. Test adverse cases: invalid credentials, abusive reconnects, restart, stale config, upgrades, firewalls, IPv6 and log spoofing.

## References
- https://www.openssh.org/security.html
- https://www.openssh.org/txt/release-10.6
- https://security-tracker.debian.org/tracker/source-package/openssh
- https://docs.docker.com/dhi/
- https://www.upwind.io/feed/openssh-vulnerabilities-cve-2025-26465-and-cve-2025-26466-enable-man-in-the-middle-and-dos-attacks
- https://security.stackexchange.com/questions/180583/what-is-the-general-approach-to-create-fips-compliant-ssh
- https://technicaldocs.nozominetworks.com/reference-guides/products/n2os/topics/fips/r_fips_protocols_ssh.html

## Production observations and review adjustments — 2026-10-29
The operator supplied a live production `sshd_config`, `fail2ban.local`, and `jail.local` running on Proxmox VE kernel `7.0.14-26-pve`. The operator reports actual tests in which Fail2Ban bans enforced through nftables/iptables prevented SFTP access. **Treat this as successful enforcement in the tested environment**, not an unverified feature; separately retain regression tests for other Docker network modes. Production values may differ from repository defaults.

### Production SSHD profile (observed)
- `LoginGraceTime 20` (the repo default `0` is a **baseline discrepancy**, not the production setting); `MaxAuthTries 3`; `MaxSessions 1`; `MaxStartups 10:30:30`.
- `PasswordAuthentication yes`, `PubkeyAuthentication no`, `KbdInteractiveAuthentication no`, `AllowUsers admin`; password authentication is intentional. Never silently switch it off.
- `ForceCommand internal-sftp` and `ChrootDirectory %h`; forwarding, tunnels and TTY disabled; `LogLevel VERBOSE`.
- Explicit curve25519/group14/group16 KEX, AES GCM/CTR and ChaCha20 ciphers, encrypt-then-MAC and SHA2 MACs, Ed25519/RSA-SHA2 host keys. These settings are **not a FIPS claim**; a FIPS profile must separately determine compatible crypto/provider.
- Validate effective `sshd -T` against real values and all applicable `Match` sections. Confirm `UsePAM`, GSSAPI, `DisableForwarding`, permission and chroot ownership in effective config rather than inferring from comments.

### Production Fail2Ban profile (observed)
- Successful nft/iptables bans reported; persistent ban database at `/config/fail2ban/fail2ban.sqlite3`, history purge 7d.
- `ignoreip = 127.0.0.1/8 192.168.2.0/24` is environment-specific; do not commit site networks into public generic defaults.
- Main SSH jail: three events/600s and 3600s ban. Cipher mismatch and bad banner jails: one event and 86400s ban. `recidive` uses repeated events/day and week-long all-port ban.
- `backend = polling` and `usedns = warn` warrant benchmarking / DNS-avoidance analysis. Inspect exact `banaction_allports` expansion, action syntax, logwhois behavior, IPv6, restoration after restart and repeat-offender logic; preserve known good ban functionality.
- Historical Unraid workflow periodically exported Fail2Ban log IPs to a router-level blocklist, with a separate Samba-sourced list. Future UniFi integration must separate detection, verified ban events, deduplication, retention, allowlist, dry-run, permissions, audit, and router API actions; keep secrets out of Git.

### Current upstream vs Debian CVE review (2026-10-29)
OpenSSH 10.6 released 2026-10-06. Debian's OpenSSH tracker reports Trixie `1:10.0p1-7+deb13u4` vulnerable to CVE-2026-59997 (internal-sftp >9 command-line argument handling), CVE-2026-59999 (DisableForwarding/PermitTunnel interaction), and CVE-2026-60000 (GSSAPI pre-auth resource consumption), with issues fixed in newer upstream/other Debian suites. **Applicability is configuration-specific**: the observed `internal-sftp` arguments are fewer than 10, `PermitTunnel no` is set, and effective GSSAPI behavior remains to be checked. Track status and risk rather than blindly equating upstream version with exploitability.
Sources:
- https://security-tracker.debian.org/tracker/source-package/openssh
- https://security-tracker.debian.org/tracker/CVE-2026-59997
- https://security-tracker.debian.org/tracker/CVE-2026-59999
- https://security-tracker.debian.org/tracker/CVE-2026-60000

### Next pass: operational acceptance tests
1. Capture sanitized `sshd -T` and package provenance, version and security tracker results.
2. Check `sshd -t`, no shell/port forwarding, login grace timing, password auth, chroot behavior, host key permissions and file transfer success.
3. Confirm Fail2Ban action expansion, firewall backend selection, bans/unbans, ban database persistence, IPv6 and recidive; record previously passed tests as evidence only when logs are available.
4. Evaluate Debian base and optional Alpine/DHI variants against the same functional tests; retain WHOIS compatibility as a requirement rather than choosing a base solely for size.
5. Define build-time scanning, update eligibility, CVE severity/applicability decisions, deployment, health checks and rollback; avoid in-place sshd replacement while accepting sessions without designed restart behavior.
\n## Implemented private-branch SSHD baseline — 2026-10-29
- Default `LoginGraceTime 20`, `MaxAuthTries 3`, `MaxSessions 1`, `MaxStartups 10:30:30`.
- Explicit password-only SFTP without PAM, keyboard-interactive, public-key, TTY, forwarding or user environment.
- Internal SFTP logs to AUTHPRIV/INFO. No forced crypto list or FIPS claim; compatibility remains to be tested.
- New `scripts/validate-security.sh` is copied to `/usr/local/bin/validate-security.sh`. Run after normal startup and host key generation: `bash /usr/local/bin/validate-security.sh`. It checks `sshd -t`, effective `sshd -T`, key restrictions and Fail2Ban readiness. Warnings do not constitute proof that packet filtering is working.
- **Important:** this audit expects the password-only profile; future key-auth and FIPS profiles should have their own assertions. It checks global effective settings, not all per-user `Match` expansions or actual SFTP transfers. Add integration/negative tests before production use.
- **Important:** the running image reads persistent `/config/sshd/sshd_config`; updated defaults do not automatically overwrite an existing production file.
- Remaining high-risk issues: entrypoint default admin credential seeding, writable config mutation via sed, APT errors masked in updater, reliable Fail2Ban startup enforcement, and effective per-network ban tests. These have deliberately not been changed in this patch.
