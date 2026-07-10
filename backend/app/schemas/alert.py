import json
from datetime import datetime

from pydantic import BaseModel, Field


class AlertCreate(BaseModel):
    type: str = Field(min_length=1, max_length=60)
    severity: str = Field(pattern="^(critical|high|medium|low)$")
    camera_id: int | None = None
    confidence: float | None = Field(default=None, ge=0, le=1)
    experimental: bool = False
    lat: float | None = None
    lng: float | None = None
    snapshot: str | None = None
    clip: str | None = None
    details: dict = {}


class AlertOut(BaseModel):
    id: int
    type: str
    severity: str
    confidence: float | None
    experimental: bool
    camera_id: int | None
    camera_name: str | None = None
    incident_id: int | None
    lat: float | None
    lng: float | None
    snapshot: str | None
    clip: str | None
    details: dict = {}
    acknowledged: bool
    resolved: bool
    false_positive: bool
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_alert(cls, alert) -> "AlertOut":
        try:
            details = json.loads(alert.details) if alert.details else {}
        except (json.JSONDecodeError, TypeError):
            details = {}
        return cls(
            id=alert.id, type=alert.type, severity=alert.severity, confidence=alert.confidence,
            experimental=alert.experimental, camera_id=alert.camera_id,
            camera_name=alert.camera.name if alert.camera else None,
            incident_id=alert.incident_id, lat=alert.lat, lng=alert.lng,
            snapshot=alert.snapshot, clip=alert.clip, details=details,
            acknowledged=alert.acknowledged, resolved=alert.resolved,
            false_positive=alert.false_positive, created_at=alert.created_at,
        )
