# Final Alpine readiness audit (source review, 2026-10-29)

This is a source-only review, NOT a completed Docker build or security test.

## 1. Image and startup
- **Configured:** root Dockerfile is alpine:edge, installs Bash, OpenSSH server/client/SFTP, WHOIS, Fail2Ban, rsyslog, iptables/nftables, shadow and version/update scripts.
- **Configured:** /opt/debug/build-versions.txt; startup pre/post upgrade reports; optional periodic APK upgrades.
- **Needs real build:** package availability on selected architecture, rsyslog facility output, Alpine nologin/useradd/chpasswd compatibility, WHOIS network lookup and Docker logging.
- **Risk:** startup update errors currently emit a warning and continue. Runtime package updates require sshd restart to load changed executable/libraries. Existing processes are NOT hot-patched.

## 2. Source of truth, multi-user and directories
- **Configured:** persistent /config/sshd/users.conf seeds missing Linux users; re-applies password or encrypted password at every startup; default ADMIN_USER=admin, ADMIN_UID=1000, ADMIN_GID=100, but ADMIN_PASS must be explicitly supplied on fresh boot. There is NO insecure admin/admin login.
- **Configured:** user homes /home/NAME owned root:root and mode 0755 for ChrootDirectory %h; new share directories use UID:GID and 2770. Existing share root permissions are preserved by default. SHARE_MOUNT_PERMS=group explicitly changes only the share directory root, including a bind-mounted host path.
- **Pending:** /config/sshd/users.conf is NOT fully exclusive: SFTP_USERS and command-line user specs still append entries and can duplicate a username. Decide precedence/deduplication policy before public release.
- **Pending:** removing a user from users.conf does not lock/delete a preexisting account. Username can also be blocked by custom AllowUsers. UID/GID mismatch refuses silent migration. Changing passwords requires container restart; no file watcher.
- **Pending:** access tests for mounted nobody:users storage, ACLs, world-writable paths, multi-user isolation and FileZilla. Never chown -R existing host mounts.
- **Fixed in this audit:** unintended literal backslash-n shell text before password update and the empty-user startup refusal was corrected.

## 3. Persistent /config
- **Configured:** initialize absent /config/{sshd,fail2ban,log,debug,userkeys}; seed missing configs; preserve existing users.conf, SSH host keys and Fail2Ban database.
- **Pending:** verify first boot with anonymous Docker VOLUME, named volume, and host bind mount. Verify existing config migration, all permissions, and restart/recreation semantics.
- **Risk:** persistent /config/fail2ban/jail.d/*.local from previous builds may retain duplicate or conflicting jail overrides; source-level consolidation cannot automatically remove them.

## 4. SSHD
- **Configured:** SFTP-only, chroot, no root login, no TTY/forwarding, 20-second auth grace, 3 auth failures and verbose auth logging.
- **Pending:** sshd -t and sshd -T using Alpine edge OpenSSH, actual FileZilla login/transfer and shell-denial. The security validation script hardcodes the password-only profile and is not FIPS-aware.
- **Pending:** optional FIPS build needs validated provider/environment; Ed25519/curve25519/ChaCha20 cannot be presumed FIPS approved.

## 5. Fail2Ban
- **Configured:** sshd, sshd-cipher-mismatch, sshd-banner-fail, recidive; persistent logs/DB, WHOIS report and no-email default; fail-closed startup gate checks sshd jail.
- **Pending:** fail2ban-client -t, startup, regex tests on OpenSSH 10.6 logs, WHOIS timeout/no-network behavior and actual iptables/nftables bans. Startup jail response is not proof of packet drops.
- **Risk:** current defaults include both iptables and nftables packages, so auto-selects iptables when present. Select backend deliberately after testing; Docker network mode may affect ban scope.

## Acceptance gates
1. Build image and inspect /opt/debug/build-versions.txt; run bash -n on entrypoint and scripts.
2. Start on isolated /config (not production), with an explicitly supplied first-boot admin password; verify boot succeeds and no secrets are printed.
3. Add second user in users.conf, test numeric identity, chroot root owner, mounted share access and FileZilla; rotate password, restart and retest.
4. Test old configs and user removal policy; prove no unintended recursive chown or config clobbering.
5. Check sshd -t/-T, SFTP operations, denied shell, connection limits and host key persistence.
6. Verify real auth.log data, all jail regexes, bans/unbans, WHOIS and recidive under Alpine.
7. Test update success/failure, running process version, restart-required alert and rollback.
8. Do not release to public repo or replace production until gates pass.
