from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..core.db import Base


class AuditLog(Base):
    """One row per sensitive action (login, password change, alert
    delete, role change, ...) — who did what, to what, from where."""

    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), default=None)
    action: Mapped[str] = mapped_column(String(100))
    resource_type: Mapped[str | None] = mapped_column(String(60), default=None)
    resource_id: Mapped[str | None] = mapped_column(String(60), default=None)
    details: Mapped[str | None] = mapped_column(default=None)  # JSON
    ip_address: Mapped[str | None] = mapped_column(String(64), default=None)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
