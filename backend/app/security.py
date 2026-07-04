"""Password hashing and JWT issuing/verification for the citizen app.

Kept deliberately small: one secret, one algorithm, one token lifetime.
The admin dashboard does not use this — it has no login of its own yet.
"""
import os
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import HTTPException, Request, status
from passlib.context import CryptContext

# In production this MUST come from an environment variable / secret store.
# A prototype-only fallback is provided so the API still boots without one.
JWT_SECRET = os.environ.get("SECURECITY_JWT_SECRET", "dev-only-insecure-secret-change-me")
JWT_ALGORITHM = "HS256"
JWT_EXPIRES_HOURS = 24 * 7  # 7 days

_pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return _pwd_ctx.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return _pwd_ctx.verify(password, password_hash)


def create_access_token(user_id: int, email: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "email": email,
        "iat": now,
        "exp": now + timedelta(hours=JWT_EXPIRES_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")


def get_current_user_id(request: Request) -> int:
    """FastAPI dependency: extracts and validates the bearer token."""
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    payload = decode_access_token(auth.removeprefix("Bearer ").strip())
    return int(payload["sub"])
