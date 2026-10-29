#!/usr/bin/env bash
# Alpine package inventory; does not print credentials.
set -Eeuo pipefail
phase="${1:-runtime}"
stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[versions] phase=$phase utc=$stamp os=$(awk -F= '/^ID=/{gsub(/"/,"",$2);print $2}' /etc/os-release)"
echo "[versions] ssh_client=$(ssh -V 2>&1)"
echo "[versions] ssh_daemon=$(sshd -V 2>&1 || true)"
for pkg in openssh-server openssh-client openssh-sftp-server fail2ban whois rsyslog apk-tools musl openssl; do
  version="$(apk info -v "$pkg" 2>/dev/null | head -n1 || true)"
  echo "[versions] package=$pkg installed=${version:-absent}"
done
echo "[versions] whois_path=$(command -v whois || echo absent)"
