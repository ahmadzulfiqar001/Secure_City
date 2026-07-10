from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from ..core.db import Base


class RefreshToken(Base):
    """The revocation table logout/refresh-rotation needs — JWTs
    themselves are stateless, so a *refresh* token has to be tracked
    server-side for logout to mean anything before it naturally expires.

    Only the SHA-256 hash of the token is stored, never the raw value —
    same principle as password_hash, in case the DB itself leaks.
    """

    __tablename__ = "refresh_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    user: Mapped["User"] = relationship(back_populates="refresh_tokens")

    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
