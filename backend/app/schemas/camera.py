import json
from datetime import datetime

from pydantic import BaseModel, Field

# Fractional (0-1) frame coordinates, top-left origin — same convention the
# ai_engine's supervision.PolygonZone consumes directly.
Zone = list[list[float]]


class CameraCreate(BaseModel):
    code: str = Field(min_length=1, max_length=20)
    name: str = Field(min_length=1, max_length=120)
    lat: float
    lng: float
    source: str | None = None
    status: str = "offline"  # online|offline|standby
    zone: Zone | None = None


class CameraUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    lat: float
    lng: float
    source: str | None = None
    status: str
    zone: Zone | None = None


class CameraOut(BaseModel):
    id: int
    code: str
    name: str
    lat: float
    lng: float
    source: str | None
    status: str
    zone: Zone | None = None
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_camera(cls, cam) -> "CameraOut":
        try:
            zone = json.loads(cam.zone) if cam.zone else None
        except (json.JSONDecodeError, TypeError):
            zone = None
        return cls(
            id=cam.id, code=cam.code, name=cam.name, lat=cam.lat, lng=cam.lng,
            source=cam.source, status=cam.status, zone=zone, created_at=cam.created_at,
        )
