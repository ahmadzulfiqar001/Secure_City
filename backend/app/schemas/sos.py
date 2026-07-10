from datetime import datetime

from pydantic import BaseModel, Field


class SOSCreate(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    alert_id: int | None = None


class SOSOut(BaseModel):
    id: int
    lat: float
    lng: float
    status: str
    alert_id: int | None
    created_at: datetime
    resolved_at: datetime | None

    model_config = {"from_attributes": True}
