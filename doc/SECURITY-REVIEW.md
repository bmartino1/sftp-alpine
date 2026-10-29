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
