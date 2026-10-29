# SFTP with Fail2Ban — Private Development

**Default base: Alpine Linux edge (rolling).** This project provides a password-capable, SFTP-only OpenSSH container with persistent configuration, Fail2Ban SSH abuse detection, optional WHOIS reporting, and bind-mounted user shares.

> **Status:** experimental private development. The Alpine build, Fail2Ban firewall enforcement and FileZilla transfer behavior have not yet been integration-tested. This repository is not a published Docker Hub image, CISA certification or FIPS-validated product. The existing public `bmartino1/sftp2` and `bmmbmm01/sftp2:latest` remain separate.

## Why Alpine edge?
The project previously used Debian because its packages and Fail2Ban/WHOIS integration were familiar and dependable. Alpine edge now offers a packaged `whois` client from the **community** repository, as well as newer rolling OpenSSH packages. The default Dockerfile installs Bash so the Bash entrypoint can be retained. It uses `apk upgrade --available` during build and at startup when `AUTO_UPDATE=suite`.

The package manager can only install releases available in Alpine's repositories. Upgrading before SSHD starts activates upgraded binaries at that launch; **it does not hot-patch a running daemon**. Redeployment from an older image resets packages to that image until startup updates run. Maintain a rollback image and backed-up `/config`.

## Build variants
```sh
docker build --pull -t sftp-private:edge-test .
docker build --pull -f Dockerfile.debian -t sftp-private:debian-test .
```
The root `Dockerfile` is the Alpine edge default. `Dockerfile.alpine` is a separate experimental Alpine variant. `Dockerfile.debian` keeps the Debian fallback.

Do **not** mount production credentials, ZFS volumes or SSH host keys when initially testing. Start with a separate `/config` and host port such as `2222:22`. See [examples/docker-compose.yml](examples/docker-compose.yml) for the test deployment, not a production prescription.

## First boot and users
The persistent `/config/sshd/users.conf` file is authoritative. On startup it creates missing users and reapplies configured credentials. Editing a password requires a restart. Existing user UID/GID drift is rejected instead of automatically reowning host data. Removing a line does not yet deprovision the account; this is a pending feature.

Supported examples (not actual credentials):
```text
admin:REPLACE_WITH_SECRET:1000:100:data
anotheruser:REPLACE_WITH_SECRET:1001:100:uploads,downloads
```
Encrypted password records use `user:hash:e:uid:gid[:directories]`. Never commit real credentials.

When `users.conf` is missing, `DEFAULT_ADMIN=true` can seed `ADMIN_USER` with numeric `ADMIN_UID`, `ADMIN_GID` and an explicitly supplied **non-placeholder** `ADMIN_PASS`. No functional `admin/admin` default is distributed. `DEFAULT_ADMIN=false` creates an empty file and the service will not expose an unconfigured SFTP listener. The environment value for `ADMIN_PASS` may be visible to Docker administrators.

**Mount shares below the chroot home**, e.g. `/home/admin/data` or `/home/anotheruser/uploads`. The home itself must remain root-owned and non-writable by the user. New share subdirectories are created with mode `2770` and the user UID/GID. Existing bind-mounted share directories retain their permissions unless `SHARE_MOUNT_PERMS=group` is explicitly set; that mode can change a host mount root's ownership (nonrecursively). Never apply recursive chown/chmod to shared host data. `PUID=0` / `PGID=0` are not SFTP account-mapping variables.

More details: [doc/USER-MANAGEMENT.md](doc/USER-MANAGEMENT.md).

## Configuration and logs
Persistent state is stored under `/config`: `sshd/sshd_config`, `sshd/users.conf`, `sshd/keys/`, `userkeys/`, `fail2ban/`, `log/`, and `debug/`. Missing defaults are seeded; existing files are not automatically migrated. SSH host keys persist to avoid changing the server identity after recreation.

`ForceCommand internal-sftp` enforces SFTP-only operations. FileZilla remains the target client. The standard profile uses password authentication and is **not FIPS-certified**; FIPS crypto requires a separate evaluated build and validated provider.

Fail2Ban uses persisted auth logs and a persistent SQLite ban database. The bundled jails are `sshd`, `sshd-cipher-mismatch`, `sshd-banner-fail`, and `recidive`. WHOIS appends ban enrichment to `/config/log/whois.log`. No email is sent by default. Existing `/config/fail2ban/jail.d/*.local` files may override newer defaults: review effective settings before migration.

## Configuration variables
| Variable | Default | Meaning |
|---|---|---|
| `TZ` | `America/Chicago` | Container timezone |
| `AUTO_UPDATE` | `suite` | Upgrade packages from configured distro; `none` disables, `custom` invokes `/config/updateapps.sh` |
| `AUTO_UPDATE_INTERVAL_HOURS` | `0` | Optional hourly-cadence unattended Alpine APK upgrades; `0` disables, changes to OpenSSH trigger restart-required log, not automatic restart |
| `DEFAULT_ADMIN` | `true` | Seed admin only if users.conf is missing |
| `ADMIN_USER` | `admin` | First-boot user |
| `ADMIN_PASS` | unset | Required secure first-boot password |
| `ADMIN_UID`, `ADMIN_GID` | `1000`, `100` | First-boot user identity |
| `F2B_REQUIRED` | `true` | Refuse SSHD startup if main Fail2Ban jail is unavailable |
| `F2B_CONFIG_MODE` | `symlink` | Persisted configuration wiring |
| `SHARE_MOUNT_PERMS` | `check` | Preserve existing shares; `group` changes direct share root only |
| `TAIL_LOGS` | `true` | Mirror auth and Fail2Ban logs to Docker stdout |
| `LOG_STREAMS` | `auth,fail2ban` | Select streamed files |
| `CLEAR_LOGS` | `false` | Archive and clear old logs if explicitly requested |
| `DEBUG_TESTING` | `false` | Write debug configuration checks |

## Build versus runtime versions
The image records a package snapshot at `/opt/debug/build-versions.txt` during build. Docker startup logs report `pre-update` and `post-update` inventories; for Alpine, each line includes the installed APK revision (rather than assuming SSHD's upstream version alone proves security status). `AUTO_UPDATE=suite` runs before SSHD starts. Optional `AUTO_UPDATE_INTERVAL_HOURS=24` performs package upgrades in the background while the container is up, but **cannot hot-replace an already-running sshd**. If OpenSSH changes it logs `RESTART REQUIRED` and writes `/config/debug/restart-required.txt`. Other daemon/library upgrades may also require a restart. Use a disposable environment before enabling this on an exposed service.

## Verification
Run these **after** starting an isolated test container:
```sh
bash /usr/local/bin/validate-security.sh
bash /usr/local/bin/security-status.sh
bash /usr/local/bin/healthcheck.sh
fail2ban-client -t
fail2ban-client status
apk info -v openssh-server fail2ban whois
command -v whois
```
These checks do not replace an actual FileZilla upload/download, SSH shell-denial test, or observed iptables/nftables packet drop. A responding Fail2Ban daemon is not equivalent to a verified ban.

## Licensing and provenance
The repository's original [MIT license](LICENSE) remains in force for repository code. Alpine and installed packages have **their own licenses**; they are not relicensed under MIT. For example, Alpine edge community `whois` is GPL-2.0-or-later. See [doc/THIRD-PARTY-LICENSES.md](doc/THIRD-PARTY-LICENSES.md) and the Alpine package index. Review distribution notice obligations before publishing derived images.

## More information
- [Development change log](doc/CHANGELOG.md)
- [Security review](doc/SECURITY-REVIEW.md)
- [Alpine and FIPS research](doc/ALPINE-FIPS-PLAN.md)
- [Private project documentation](doc/README.md)
- [Public project](https://github.com/bmartino1/sftp2)
- [Unraid support thread](https://forums.unraid.net/topic/189050-support-sftp-fail2ban)
