from __future__ import annotations

from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from ..core.security import utcnow
from ..models import Alert, Incident


class IncidentRepository:
    def __init__(self, db: Session):
        self.db = db

    def list(self, page: int, page_size: int, status: str | None, severity: str | None) -> tuple[list[Incident], int]:
        stmt = select(Incident).options(joinedload(Incident.alerts))
        if status:
            stmt = stmt.where(Incident.status == status)
        if severity:
            stmt = stmt.where(Incident.severity == severity)

        total = self.db.scalar(select(func.count()).select_from(stmt.subquery()))
        stmt = stmt.order_by(Incident.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        rows = list(self.db.execute(stmt).unique().scalars())
        return rows, total or 0

    def get(self, incident_id: int) -> Incident | None:
        stmt = select(Incident).options(joinedload(Incident.alerts)).where(Incident.id == incident_id)
        return self.db.execute(stmt).unique().scalar_one_or_none()

    def _link_alerts(self, incident: Incident, alert_ids: list[int]) -> None:
        alerts = list(self.db.execute(select(Alert).where(Alert.id.in_(alert_ids))).scalars())
        incident.alerts = alerts

    def create(
        self, title: str, description: str | None, severity: str,
        camera_id: int | None, created_by_id: int, alert_ids: list[int],
    ) -> Incident:
        incident = Incident(
            title=title, description=description, severity=severity,
            camera_id=camera_id, created_by_id=created_by_id,
        )
        self.db.add(incident)
        self.db.flush()
        if alert_ids:
            self._link_alerts(incident, alert_ids)
        self.db.commit()
        self.db.refresh(incident)
        return incident

    def update(
        self, incident: Incident, title: str, description: str | None,
        status: str, severity: str, alert_ids: list[int] | None,
    ) -> Incident:
        incident.title, incident.description = title, description
        was_resolved = incident.status == "resolved"
        incident.status, incident.severity = status, severity
        if status == "resolved" and not was_resolved:
            incident.resolved_at = utcnow()
        elif status != "resolved":
            incident.resolved_at = None
        if alert_ids is not None:
            self._link_alerts(incident, alert_ids)
        self.db.commit()
        self.db.refresh(incident)
        return incident

    def delete(self, incident: Incident) -> None:
        self.db.delete(incident)
        self.db.commit()
