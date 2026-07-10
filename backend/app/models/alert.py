from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from ..core.db import Base


class Alert(Base):
    __tablename__ = "alerts"

    id: Mapped[int] = mapped_column(primary_key=True)
    type: Mapped[str] = mapped_column(String(60))
    severity: Mapped[str] = mapped_column(String(20))  # critical|high|medium|low
    confidence: Mapped[float | None] = mapped_column(Float, default=None)
    experimental: Mapped[bool] = mapped_column(Boolean, default=False)

    camera_id: Mapped[int | None] = mapped_column(ForeignKey("cameras.id"), default=None)
    camera: Mapped["Camera"] = relationship(back_populates="alerts")

    incident_id: Mapped[int | None] = mapped_column(ForeignKey("incidents.id"), default=None)
    incident: Mapped["Incident"] = relationship(back_populates="alerts")

    lat: Mapped[float | None] = mapped_column(Float, default=None)
    lng: Mapped[float | None] = mapped_column(Float, default=None)
    snapshot: Mapped[str | None] = mapped_column(String(255), default=None)
    clip: Mapped[str | None] = mapped_column(String(255), default=None)
    details: Mapped[str | None] = mapped_column(default=None)  # JSON blob

    acknowledged: Mapped[bool] = mapped_column(Boolean, default=False)
    resolved: Mapped[bool] = mapped_column(Boolean, default=False)
    false_positive: Mapped[bool] = mapped_column(Boolean, default=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
