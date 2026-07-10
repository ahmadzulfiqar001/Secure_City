from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from ..core.db import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    phone: Mapped[str | None] = mapped_column(String(32), default=None)
    password_hash: Mapped[str] = mapped_column(String(255))
    is_verified: Mapped[bool] = mapped_column(default=False)
    preferences: Mapped[str | None] = mapped_column(default=None)  # JSON blob

    otp_code: Mapped[str | None] = mapped_column(String(6), default=None)
    otp_purpose: Mapped[str | None] = mapped_column(String(20), default=None)  # verify|reset
    otp_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)

    role_id: Mapped[int | None] = mapped_column(ForeignKey("roles.id"), default=None)
    role: Mapped["Role"] = relationship(back_populates="users")

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    contacts: Mapped[list["EmergencyContact"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    notifications: Mapped[list["Notification"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    sos_events: Mapped[list["SOSEvent"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(back_populates="user", cascade="all, delete-orphan")
