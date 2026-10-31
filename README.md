# SFTP with Fail2Ban — Alpine Edge

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-bmmbmm01%2Fsftp-2496ED?logo=docker&logoColor=white)](https://hub.docker.com/r/bmmbmm01/sftp)
[![GitHub](https://img.shields.io/badge/Source-bmartino1%2Fsftp--alpine-181717?logo=github&logoColor=white)](https://github.com/bmartino1/sftp-alpine)

An SFTP-only Docker image based on **Alpine Linux edge (rolling)** with OpenSSH, OpenSSL, Fail2Ban, rsyslog, WHOIS and persistent configuration. The standard SSHD profile restricts interactive shells, SSH forwarding, X11 and tunnels while supporting SFTP clients such as FileZilla.

**Related Debian image:** [GitHub sftp-debian](https://github.com/bmartino1/sftp-debian) · [Docker Hub sftp2](https://hub.docker.com/r/bmmbmm01/sftp2). Alpine and Debian are **separate images**; using one does not update the other.

> **Rolling-release notice:** Alpine edge packages and availability can change without a fixed release schedule. Always test fresh builds and keep a previous known-good image. This is a hardened configuration, **not** a FIPS-certified or CISA-certified product.

## Features

- Alpine edge packages, with `apk upgrade --available` during image build.
- Optional `AUTO_UPDATE=suite` at startup and opt-in periodic updates; running SSHD is **not** hot-patched.
- Four Fail2Ban jails: `sshd`, `sshd-cipher-mismatch`, `sshd-banner-fail`, and `recidive`.
- Persistent SSH host keys, user accounts, security logs, Fail2Ban configuration and ban database under `/config`.
- SFTP chroot homes with writable shares mounted **below** `/home/USERNAME`; existing share permissions preserved by default.
- Build and runtime version reporting, health check and security diagnostics.

## Build and run

The repository's root `Dockerfile` builds the **Alpine edge** image.

```bash
git clone https://github.com/bmartino1/sftp-alpine.git
cd sftp-alpine
docker build --pull --no-cache -t sftp-alpine:edge-local .
```

Use an isolated directory for your first run; don't mount production keys or user data before validation.

```bash
mkdir -p ./test-config ./test-share
# Choose a unique admin password for this disposable first boot.
read -rsp "Test admin password: " ADMIN_PASS; echo
export ADMIN_PASS
docker run -d --name sftp-alpine-test \
  --cap-add=NET_ADMIN --cap-add=NET_RAW \
  -p 2222:22 \
  -e TZ=America/Chicago \
  -e AUTO_UPDATE=none \
  -e DEFAULT_ADMIN=true \
  -e ADMIN_USER=admin \
  -e ADMIN_PASS \
  -v "$(pwd)/test-config:/config" \
  -v "$(pwd)/test-share:/home/admin/data" \
  sftp-alpine:edge-local
unset ADMIN_PASS
```

The example above seeds `test-config/sshd/users.conf` with the chosen first-boot password. For manual account management, set `DEFAULT_ADMIN=false`, prepare `test-config/sshd/users.conf` with a record such as `admin:YOUR_UNIQUE_PASSWORD:1000:100:data`, and then start the container. Do not commit real passwords, host keys or `/config` contents.

For Docker Compose, use the repository-root [docker-compose.yml](https://github.com/bmartino1/sftp-alpine/blob/main/docker-compose.yml). Set `ADMIN_PASS` in a local, untracked `.env` file before running `docker compose up -d --build`. The template builds the local Alpine `Dockerfile`; remove its `build` section to pull the published Docker Hub image instead.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `TZ` | `America/Chicago` | Timezone for logs and container processes |
| `AUTO_UPDATE` | `suite` | `suite` updates Alpine packages at startup; `none` disables; `custom` calls `/config/updateapps.sh` |
| `AUTO_UPDATE_INTERVAL_HOURS` | `0` when omitted | Optional periodic APK upgrade interval; `0` disables; upgraded SSHD requires a controlled restart |
| `DEFAULT_ADMIN` | `true` | On **first boot only**, seed the admin if `users.conf` is absent |
| `ADMIN_USER` | `admin` | Used only if `/config/sshd/users.conf` does not already exist and `DEFAULT_ADMIN=true` |
| `ADMIN_PASS` | unset | Required for automatic first-boot seeding when `users.conf` is missing; `password`, `admin` and `change-me-now` are rejected by the entrypoint |
| `ADMIN_UID` | `1000` | First-boot admin user ID |
| `ADMIN_GID` | `100` | First-boot admin group ID |
| `SFTP_USERS` | unset | Whitespace-separated inline user specifications for the **current startup**; these are not written back to `users.conf` |
| `PASSWORD_AUTH` | unset | Override `PasswordAuthentication` in the active SSHD config |
| `ALLOW_USERS` | unset | SSHD `AllowUsers` allowlist |
| `F2B_CONFIG_MODE` | `symlink` | `symlink`, `overlay`, `noclobber`, or `replace` |
| `F2B_REQUIRED` | `true` | Refuse SSHD startup if the main Fail2Ban jail is not ready |
| `SHARE_MOUNT_PERMS` | `check` | Preserve existing share permissions; `group` opts into a nonrecursive ownership/mode change at share roots |
| `DISABLE_IMKLOG` | `true` | Disable container-hostile rsyslog kernel log input |
| `MODE` | `start` | `start` serves SFTP; `seed` prepares defaults and exits (subject to account checks) |
| `TAIL_LOGS` | `true` | Mirror selected persisted log files to Docker output |
| `LOG_STREAMS` | `auth,fail2ban` | Comma-separated `auth`, `fail2ban`, `whois` |
| `DEBUG_TESTING` | `false` | Write preflight diagnostics to `/config/debug` |
| `MAIL_SERVER` | `false` | Permit custom Fail2Ban mail actions when explicitly enabled |
| `CLEAR_LOGS` | `false` | Archive and clear prior logs when enabled |
| `PUID`, `PGID` | Not used for SFTP identity | Configure user UID/GID in `users.conf` or initial `ADMIN_UID`/`ADMIN_GID` |

**Alpine versus Debian admin synchronization (source verified, fresh-build runtime verification still needed):** In this Alpine implementation, `ADMIN_USER` and `ADMIN_PASS` only seed a **missing** `users.conf` when `DEFAULT_ADMIN=true`. Changing `ADMIN_PASS` later does **not** rewrite an existing account. Edit `/config/sshd/users.conf` and restart to change a persisted password. Similarly, `SFTP_USERS` is applied at startup but is not persisted to that file. Do not assume Debian `sftp2` environment synchronization behavior applies to this image.

## Persistent configuration and permissions

Mount the host's application data at `/config`. Key locations:

| Path | Purpose |
|---|---|
| `/config/sshd/users.conf` | Persisted user definitions and password hashes |
| `/config/sshd/sshd_config` | SSHD configuration, seeded when missing |
| `/config/sshd/keys/` | Persistent SSH server host keys |
| `/config/fail2ban/` | Persistent Fail2Ban settings and SQLite state |
| `/config/log/` | Auth, Fail2Ban, and WHOIS logs |
| `/config/debug/` | Runtime diagnostics and restart-required notice |

Supported account records:

```text
admin:YOUR_UNIQUE_PASSWORD:1000:100:data
user2:ANOTHER_UNIQUE_PASSWORD:1001:100:uploads
user3:ENCRYPTED_PASSWORD_HASH:e:1002:100:uploads
```

Chroot directories (`/home/admin`) must remain `root:root` and non-writable. Mount your files under a child directory (`/home/admin/data`). Existing host ownership/ACLs are respected unless you explicitly enable `SHARE_MOUNT_PERMS=group`. Use `NET_ADMIN` and `NET_RAW` when you need Fail2Ban's firewall enforcement.

If migrating a running server, **preserve both `users.conf` and the existing SSH host keys**. Losing the keys changes the SSH server identity and prompts clients to reverify it.

## Updates, verification and security

`AUTO_UPDATE=suite` upgrades available Alpine edge packages before SSHD starts. Optional `AUTO_UPDATE_INTERVAL_HOURS=24` enables periodic checks; changes to OpenSSH require a deliberate restart to run updated binaries and libraries. An old image may return to older installed packages when recreated; rebuild and redeploy regularly.

After starting the container:

```bash
docker exec sftp-alpine-test ssh -V
docker exec sftp-alpine-test openssl version
docker exec sftp-alpine-test fail2ban-client status
docker exec sftp-alpine-test sshd -t
docker inspect --format '{{.State.Health.Status}}' sftp-alpine-test
```

Verify authentication and read/write permissions using a test SFTP client and confirm that Fail2Ban bans block real unwanted connections. A jail showing as running is not itself proof of firewall enforcement. Docker NAT or VPN routing may affect which client IP SSHD sees.

Source code is covered by [LICENSE](https://github.com/bmartino1/sftp-alpine/blob/main/LICENSE); included Linux packages retain their own licenses. See [third-party license notes](https://github.com/bmartino1/sftp-alpine/blob/main/doc/THIRD-PARTY-LICENSES.md) and [user-management guidance](https://github.com/bmartino1/sftp-alpine/blob/main/doc/USER-MANAGEMENT.md).

For support, use [the Unraid SFTP support thread](https://forums.unraid.net/topic/189050-support-sftp-fail2ban).
