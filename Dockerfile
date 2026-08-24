# Mathesar — Railway wrapper image.
#
# Upstream ships no authentication bootstrap: /complete_installation/ is an
# unauthenticated form that creates the first superuser, so on a public URL the
# first stranger to load the page owns the instance and the deployer is locked
# out permanently (password recovery is an emailed link, and a fresh deploy has
# no SMTP). This wrapper seeds the admin account before the HTTP port is bound,
# re-applies the credential on every boot so a redeploy is a working password
# reset, refuses to start without a password, keeps uploaded data files on the
# volume, and sizes Gunicorn from the container's own cgroup limits.
FROM mathesar/mathesar:0.12.0

COPY railway-seed-admin.py /railway/seed-admin.py
COPY railway-entrypoint.sh /railway/entrypoint.sh
RUN chmod +x /railway/entrypoint.sh

ENV MEDIA_ROOT=/data/media \
    MATHESAR_ADMIN_USERNAME=admin

ENTRYPOINT ["/railway/entrypoint.sh"]
