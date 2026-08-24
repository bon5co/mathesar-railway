# mathesar-railway

Railway wrapper image for [Mathesar](https://mathesar.org) — the open-source web UI for
your own PostgreSQL database (spreadsheet-style table editing, relationships, permissions).

Published image: `ghcr.io/bon5co/mathesar-railway:0.12.0`

## What this wrapper changes

1. **Closes the installation-claim window.** Upstream's `/complete_installation/` route is
   reachable by anyone until a superuser exists, and the account it creates is
   `is_superuser = True`. On a public Railway URL that means the first stranger to load the
   page owns the instance, and the deployer is locked out permanently (Mathesar's recovery
   path is an emailed reset link, and a fresh deploy has no SMTP). The entrypoint seeds the
   admin account *before* gunicorn binds the port, so the route is already closed when the
   first request arrives.
2. **Refuses to boot without an admin password**, rather than starting with the claim window
   open. It also fails fast on a missing database variable or `SECRET_KEY`.
3. **Re-applies the admin password on every boot**, which makes a redeploy a working password
   reset — the only recovery an SMTP-less deploy has.
4. **Persists uploaded data files** by pointing `MEDIA_ROOT` at `/data/media` on the Railway
   volume. Upstream defaults it to `BASE_DIR/.media/`, on the disposable container layer.
5. **Sizes Gunicorn from the container's cgroup** (`cpu.max`, then capped by `memory.max` at
   roughly 256 MiB per worker) instead of a fixed worker count.
6. **Does not pass `-f`** to `bin/mathesar`, so the in-container Postgres fallback can never
   silently mask a misconfigured external database.

## Environment

| Variable | Required | Notes |
| --- | --- | --- |
| `MATHESAR_ADMIN_USERNAME` | no | defaults to `admin` |
| `MATHESAR_ADMIN_PASSWORD` | yes | boot fails if empty |
| `SECRET_KEY` | yes | Django secret |
| `POSTGRES_HOST` / `POSTGRES_PORT` / `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | yes | internal database |
| `MEDIA_ROOT` | no | defaults to `/data/media` |
| `PORT` | no | injected by Railway |
