from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..core.db import Base


class DetectionLog(Base):
    """Raw per-frame detections from the AI engine — a fuller record than
    Alert (which only stores confirmed, alert-worthy events). Feeds the
    accuracy analytics (false positive/negative rates per class/camera)."""

    __tablename__ = "detection_logs"

    id: Mapped[int] = mapped_column(primary_key=True)
    camera_id: Mapped[int | None] = mapped_column(ForeignKey("cameras.id"), default=None)
    model_name: Mapped[str] = mapped_column(String(60))
    class_name: Mapped[str] = mapped_column(String(60))
    confidence: Mapped[float] = mapped_column(Float)
    track_id: Mapped[int | None] = mapped_column(Integer, default=None)
    bbox: Mapped[str | None] = mapped_column(default=None)  # JSON [x1,y1,x2,y2]

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
