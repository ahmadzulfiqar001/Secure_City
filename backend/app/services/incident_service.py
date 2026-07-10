from __future__ import annotations

from sqlalchemy.orm import Session

from ..core.errors import NotFoundError
from ..models import Incident
from ..repositories.audit_log_repository import AuditLogRepository
from ..repositories.incident_repository import IncidentRepository


class IncidentService:
    def __init__(self, db: Session):
        self.incidents = IncidentRepository(db)
        self.audit = AuditLogRepository(db)

    def list(self, page: int, page_size: int, status: str | None, severity: str | None) -> tuple[list[Incident], int]:
        return self.incidents.list(page, page_size, status, severity)

    def get(self, incident_id: int) -> Incident:
        incident = self.incidents.get(incident_id)
        if not incident:
            raise NotFoundError("Incident not found")
        return incident

    def create(
        self, title: str, description: str | None, severity: str, camera_id: int | None,
        alert_ids: list[int], user_id: int, ip: str | None,
    ) -> Incident:
        incident = self.incidents.create(title, description, severity, camera_id, user_id, alert_ids)
        self.audit.log("incident_create", user_id=user_id, resource_type="incident", resource_id=str(incident.id), ip_address=ip)
        return incident

    def update(
        self, incident_id: int, title: str, description: str | None, status: str,
        severity: str, alert_ids: list[int] | None, user_id: int, ip: str | None,
    ) -> Incident:
        incident = self.get(incident_id)
        incident = self.incidents.update(incident, title, description, status, severity, alert_ids)
        self.audit.log("incident_update", user_id=user_id, resource_type="incident", resource_id=str(incident_id), ip_address=ip)
        return incident

    def delete(self, incident_id: int, user_id: int, ip: str | None) -> None:
        incident = self.get(incident_id)
        self.audit.log("incident_delete", user_id=user_id, resource_type="incident", resource_id=str(incident_id), ip_address=ip)
        self.incidents.delete(incident)
