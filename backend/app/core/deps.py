"""FastAPI dependencies shared across routers: DB session (re-exported),
the current authenticated user, and role-based access checks.
"""
import jwt
from fastapi import Depends, Header
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from .config import settings
from .db import get_db
from .errors import UnauthorizedError
from .security import decode_access_token

__all__ = ["get_db", "get_current_user", "require_role", "require_permission", "require_engine_key"]

_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
):
    from ..models import User  # local import avoids a core -> models -> core cycle

    if credentials is None:
        raise UnauthorizedError("Missing bearer token")
    try:
        payload = decode_access_token(credentials.credentials)
    except jwt.ExpiredSignatureError:
        raise UnauthorizedError("Token expired")
    except jwt.InvalidTokenError:
        raise UnauthorizedError("Invalid token")

    if payload.get("type") != "access":
        raise UnauthorizedError("Not an access token")

    user = db.get(User, int(payload["sub"]))
    if user is None:
        raise UnauthorizedError("User not found")
    return user


def require_role(*allowed_roles: str):
    """Usage: `Depends(require_role("admin", "operator"))` — 403s anyone
    whose role isn't in the list (or who has no role at all)."""

    def _check(user=Depends(get_current_user)):
        role_name = user.role.name if user.role else None
        if role_name not in allowed_roles:
            from .errors import AppError
            raise AppError(f"Requires one of roles: {', '.join(allowed_roles)}", status_code=403)
        return user

    return _check


def require_permission(*any_of: str):
    """Usage: `Depends(require_permission("alerts:write"))` — checks the
    seeded Role -> Permission mapping rather than a hardcoded role name, so
    granting/revoking access to a resource is a data change (seed.py /
    future admin UI), not a code change."""

    def _check(user=Depends(get_current_user)):
        from .errors import AppError

        perms = {p.name for p in user.role.permissions} if user.role else set()
        if not perms.intersection(any_of):
            raise AppError(f"Requires one of permissions: {', '.join(any_of)}", status_code=403)
        return user

    return _check


def require_engine_key(x_engine_key: str | None = Header(default=None)) -> None:
    """Usage: `Depends(require_engine_key)` — gates the ai_engine's ingest
    routes with the shared secret instead of a user JWT, since the AI
    engine is a worker process with no human user behind it."""
    if not x_engine_key or x_engine_key != settings.engine_key:
        raise UnauthorizedError("Invalid or missing engine key")
