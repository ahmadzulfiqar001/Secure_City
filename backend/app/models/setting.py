from datetime import datetime

from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..core.db import Base


class Setting(Base):
    """Generic runtime-configurable key/value store (feature flags,
    tunable thresholds, etc.) — an alternative to hardcoding values that
    an admin might reasonably want to change without a deploy."""

    __tablename__ = "settings"

    id: Mapped[int] = mapped_column(primary_key=True)
    key: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    value: Mapped[str | None] = mapped_column(default=None)  # JSON-encoded
    description: Mapped[str | None] = mapped_column(default=None)

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
