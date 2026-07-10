from pydantic import BaseModel, Field

from .camera import Zone


class EngineCameraOut(BaseModel):
    id: int
    code: str
    name: str
    lat: float
    lng: float
    source: str | None
    status: str
    zone: Zone | None = None


class DetectionLogIn(BaseModel):
    model_name: str = Field(min_length=1, max_length=60)
    class_name: str = Field(min_length=1, max_length=60)
    confidence: float = Field(ge=0, le=1)
    track_id: int | None = None
    bbox: list[float] | None = None


class DetectionBatchIn(BaseModel):
    camera_code: str
    detections: list[DetectionLogIn]
