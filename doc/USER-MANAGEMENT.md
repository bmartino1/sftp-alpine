# SFTP User Lifecycle and Permissions

## Source of truth
- Persistent `/config/sshd/users.conf` is authoritative on **container startup**. Do not silently overwrite it with environment variables once the file exists.
- Supported records:
  - `admin:secret:1000:100:uploads,downloads`
  - `user2:another-secret:1001:100:data`
  - `user2:hashed-value:e:1001:100:data`
- The container creates missing Linux users and reapplies credentials to existing users each start. A changed password in users.conf becomes active **after a container restart**, not immediately while the SSHD process runs.
- UID/GID mismatch for an existing account fails startup rather than silently changing identity of mounted storage.
- Each user gets `/home/NAME` root:root mode 0755 (safe chroot), while new writable subdirectories get the user UID/GID and 2770. Existing bind-mount ownership and content are preserved unless explicitly opted in through `SHARE_MOUNT_PERMS=group`.
- FileZilla needs permission to the mounted directory *inside* each chroot. Mounting to `/home/user2/data` is appropriate; directly mounting at `/home/brandon` generally breaks root-owned chroot restrictions.
- Existing global `AllowUsers admin` in a **custom** sshd_config will block newly added users; update its allowlist when adding named users. Default repository config does not force an allowlist.
- SFTP users receive a nonlogin shell; `ForceCommand internal-sftp` is still enforced.
- Removing a line does not yet automatically delete the Linux account or mounted data. Deprovisioning requires a separate explicit removal workflow.
- `DEFAULT_ADMIN=true` is a convenience **only with an explicitly supplied non-placeholder** `ADMIN_PASS`, and only if users.conf does not exist. The image intentionally does not ship functional `admin/admin` network credentials. Set `DEFAULT_ADMIN=false` to bootstrap with an empty file, then add users.
- For production, prefer a root-only user file with hashed passwords and do not commit secrets. `ADMIN_PASS` environment variables are visible in container metadata; secret-file support is future work.

## Suggested controlled test
1. Use a fresh isolated /config and no production share mounts; explicitly supply initial admin credentials or a prepared users.conf.
2. Start and confirm `id admin`, `stat -c '%U:%G %a' /home/admin`, `sshd -t`, `fail2ban-client status sshd`.
3. Add a second user with distinct UID; mount a disposable directory to /home/thatuser/data; restart.
4. Verify FileZilla login, upload, download and that no interactive SSH shell works.
5. Change only the user's password in users.conf; restart; check old password fails and new one succeeds.
6. Test UID mismatch: container should refuse unintended migration. Test persistence across recreation and ensure host files are not recursively chowned.
7. Test an explicit SSHD AllowUsers allowlist for all intended users; test logout and reconnection.

**Not yet integration-tested:** These startup behaviors must be verified on Alpine edge and Debian before production use.
