from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from ..core.db import Base


class Incident(Base):
    """Groups related alerts into a single trackable case (e.g. several
    detections at the same camera during one event)."""

    __tablename__ = "incidents"

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str | None] = mapped_column(default=None)
    status: Mapped[str] = mapped_column(String(20), default="open")  # open|investigating|resolved
    severity: Mapped[str] = mapped_column(String(20), default="medium")

    camera_id: Mapped[int | None] = mapped_column(ForeignKey("cameras.id"), default=None)
    created_by_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), default=None)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)

    alerts: Mapped[list["Alert"]] = relationship(back_populates="incident")
