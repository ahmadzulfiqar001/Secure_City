"""Password hashing, JWT access tokens, opaque refresh tokens, and OTP
codes — every low-level crypto/token primitive the Auth module needs.
"""
import hashlib
import re
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from passlib.context import CryptContext

from .config import settings

_pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return _pwd_ctx.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return _pwd_ctx.verify(password, password_hash)


def validate_password_strength(password: str) -> str | None:
    """Returns an error message if the password is too weak, else None."""
    if len(password) < settings.password_min_length:
        return f"Password must be at least {settings.password_min_length} characters"
    if not re.search(r"[A-Z]", password):
        return "Password must contain at least one uppercase letter"
    if not re.search(r"[a-z]", password):
        return "Password must contain at least one lowercase letter"
    if not re.search(r"\d", password):
        return "Password must contain at least one digit"
    return None


# ── JWT access tokens (short-lived, stateless — never revoked individually,
#    logout instead revokes the refresh token that would issue new ones) ──
def create_access_token(user_id: int, role: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": role,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=settings.jwt_access_ttl_minutes),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict:
    return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])


# ── Refresh tokens: opaque random strings, not JWTs — only their SHA-256
#    hash is ever persisted (see RefreshToken model), so a raw token is
#    only ever known to the client that received it. ──────────────────────
def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def utcnow() -> datetime:
    """Naive UTC — SQLite round-trips `DateTime(timezone=True)` columns as
    naive datetimes regardless of what's written, so every datetime that
    gets persisted and later compared uses this consistently instead of
    mixing aware/naive and raising TypeError on comparison."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def refresh_token_expiry() -> datetime:
    return utcnow() + timedelta(days=settings.jwt_refresh_ttl_days)


# ── OTP codes (email verification / password reset) ─────────────────────
def generate_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def otp_expiry() -> datetime:
    return utcnow() + timedelta(minutes=settings.otp_ttl_minutes)
