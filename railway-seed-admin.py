"""Seed (or re-seed) Mathesar's superuser account before the web server binds.

Upstream has no non-interactive path to create the first user: the only route
is the unauthenticated /complete_installation/ form, which hands the account to
whoever loads it first. Running this before Gunicorn starts closes that window,
and running it on every boot makes a redeploy a working password reset -- the
only recovery a fresh deploy has, since Django's reset flow needs SMTP.
"""
import os
import sys

import django

sys.path.insert(0, "/code")


def main() -> int:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")
    django.setup()

    from django.contrib.auth import get_user_model

    username = (os.environ.get("MATHESAR_ADMIN_USERNAME") or "admin").strip()
    password = os.environ.get("MATHESAR_ADMIN_PASSWORD") or ""
    if not password:
        sys.stderr.write("mathesar-railway: MATHESAR_ADMIN_PASSWORD is empty\n")
        return 1

    user_model = get_user_model()
    user, created = user_model.objects.get_or_create(username=username)
    user.is_superuser = True
    user.is_staff = True
    user.is_active = True
    user.password_change_needed = False
    user.set_password(password)
    user.save()

    others = user_model.objects.filter(is_superuser=True).exclude(pk=user.pk).count()
    print(
        "mathesar-railway: admin '%s' %s (other superusers: %d)"
        % (username, "created" if created else "password re-applied", others)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
