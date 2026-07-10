from datetime import datetime

from pydantic import BaseModel, Field


class IncidentCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    severity: str = "medium"
    camera_id: int | None = None
    alert_ids: list[int] = []


class IncidentUpdate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    status: str  # open|investigating|resolved
    severity: str
    alert_ids: list[int] | None = None


class IncidentOut(BaseModel):
    id: int
    title: str
    description: str | None
    status: str
    severity: str
    camera_id: int | None
    created_by_id: int | None
    alert_ids: list[int] = []
    created_at: datetime
    resolved_at: datetime | None

    model_config = {"from_attributes": True}

    @classmethod
    def from_incident(cls, incident) -> "IncidentOut":
        data = cls.model_validate(incident)
        data.alert_ids = [a.id for a in incident.alerts]
        return data
