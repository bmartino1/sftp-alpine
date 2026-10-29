#!/usr/bin/env bash
# Optional periodic Alpine updater. Not a daemon hot-patcher.
set -Eeuo pipefail
hours="${AUTO_UPDATE_INTERVAL_HOURS:-0}"
[[ "$hours" =~ ^[0-9]+$ ]] || { echo "[periodic-update][ERROR] invalid interval" >&2; exit 2; }
(( hours > 0 )) || exit 0
while sleep "$((hours*3600))"; do
  echo "[periodic-update] starting UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  before="$(apk info -v openssh-server 2>/dev/null | head -n1 || true)"
  if /usr/local/bin/update-inplace.sh suite; then
    after="$(apk info -v openssh-server 2>/dev/null | head -n1 || true)"
    /usr/local/bin/report-versions.sh periodic
    if [[ "$before" != "$after" ]]; then
      echo "[periodic-update][RESTART REQUIRED] OpenSSH package changed: $before -> $after"
      echo "[periodic-update][RESTART REQUIRED] Recreate/restart service in controlled window; existing sshd processes may use old binary/libraries."
      printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ) OpenSSH: $before -> $after" > /config/debug/restart-required.txt
    fi
  else
    echo "[periodic-update][ERROR] apk upgrade failed; inspect logs" >&2
  fi
done
