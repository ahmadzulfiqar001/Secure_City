from datetime import datetime

from sqlalchemy import DateTime, Float, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from ..core.db import Base


class Camera(Base):
    __tablename__ = "cameras"

    id: Mapped[int] = mapped_column(primary_key=True)
    code: Mapped[str] = mapped_column(String(20), unique=True, index=True)  # e.g. "CAM-01"
    name: Mapped[str] = mapped_column(String(120))
    lat: Mapped[float] = mapped_column(Float)
    lng: Mapped[float] = mapped_column(Float)
    source: Mapped[str | None] = mapped_column(String(255), default=None)  # rtsp/file path/webcam index
    status: Mapped[str] = mapped_column(String(20), default="offline")  # online|offline|standby
    zone: Mapped[str | None] = mapped_column(default=None)  # JSON polygon [[x,y],...], fractional 0-1 frame coords

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    alerts: Mapped[list["Alert"]] = relationship(back_populates="camera")
