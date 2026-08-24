#!/usr/bin/env bash
# Railway boot sequence for Mathesar.
#
# Order matters: migrate, seed the admin, and only then bind the port. Seeding
# after the server is listening would leave the claim window open for as long
# as the first request takes to arrive.
set -euo pipefail

log() { echo "[railway] $*"; }

if [[ -z "${MATHESAR_ADMIN_PASSWORD:-}" ]]; then
  echo "[railway] MATHESAR_ADMIN_PASSWORD is not set. Refusing to start: without" >&2
  echo "[railway] an admin account, Mathesar serves an unauthenticated setup form" >&2
  echo "[railway] that lets any visitor claim this instance." >&2
  exit 1
fi

for required in POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD SECRET_KEY; do
  if [[ -z "${!required:-}" ]]; then
    echo "[railway] ${required} is not set. Refusing to start." >&2
    exit 1
  fi
done

# Uploaded data files (CSV/TSV imports) live under MEDIA_ROOT, which is on the
# volume. Create it before Django touches it.
mkdir -p "${MEDIA_ROOT:-/data/media}"

# Gunicorn reads WEB_CONCURRENCY. Upstream's docs suggest 2*cores+1, but a
# container reports the HOST's core count, so size from the cgroup quota and
# from the memory limit -- each sync worker is a full Django process.
if [[ -z "${WEB_CONCURRENCY:-}" ]]; then
  cpus=2
  if [[ -r /sys/fs/cgroup/cpu.max ]]; then
    read -r quota period < /sys/fs/cgroup/cpu.max || true
    if [[ "${quota}" != "max" && -n "${period:-}" && "${period}" -gt 0 ]]; then
      cpus=$(( quota / period ))
    fi
  fi
  [[ "${cpus}" -lt 1 ]] && cpus=1
  workers=$(( 2 * cpus + 1 ))

  mem_workers=${workers}
  if [[ -r /sys/fs/cgroup/memory.max ]]; then
    mem=$(cat /sys/fs/cgroup/memory.max)
    if [[ "${mem}" != "max" ]]; then
      # ~256 MiB of resident memory per Django worker, measured on 0.12.0.
      mem_workers=$(( mem / 268435456 ))
    fi
  fi
  [[ "${mem_workers}" -lt 1 ]] && mem_workers=1
  [[ "${mem_workers}" -lt "${workers}" ]] && workers=${mem_workers}
  [[ "${workers}" -gt 9 ]] && workers=9

  export WEB_CONCURRENCY="${workers}"
  log "cpu_quota=${cpus} WEB_CONCURRENCY=${WEB_CONCURRENCY}"
fi

cd /code

log "running migrations"
# Static collection is NOT skipped: the image ships no staticfiles manifest, and Django's
# ManifestStaticFilesStorage raises "Missing staticfiles manifest entry" on every page without one.
python3 -m mathesar.install

log "seeding admin account"
python3 /railway/seed-admin.py

# No -f: upstream's fallback silently starts an in-container Postgres when the
# database variables do not resolve, which would put every table on the
# disposable layer while the deploy still reports healthy.
log "starting Mathesar on port ${PORT:-8000}"
exec bash ./bin/mathesar run -n -e -p "${PORT:-8000}"
