import json
from datetime import datetime

from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, joinedload

from ..models import Alert, Camera

SORTABLE_FIELDS = {"created_at": Alert.created_at, "severity": Alert.severity, "type": Alert.type}


class AlertRepository:
    def __init__(self, db: Session):
        self.db = db

    def _base_query(
        self,
        severity: str | None,
        status: str | None,
        camera_id: int | None,
        date_from: datetime | None,
        date_to: datetime | None,
        search: str | None,
    ):
        stmt = select(Alert).options(joinedload(Alert.camera)).outerjoin(Camera)

        if severity:
            stmt = stmt.where(Alert.severity == severity)
        if camera_id:
            stmt = stmt.where(Alert.camera_id == camera_id)
        if date_from:
            stmt = stmt.where(Alert.created_at >= date_from)
        if date_to:
            stmt = stmt.where(Alert.created_at <= date_to)
        if search:
            like = f"%{search.lower()}%"
            stmt = stmt.where(or_(func.lower(Alert.type).like(like), func.lower(Camera.name).like(like)))

        if status == "acknowledged":
            stmt = stmt.where(Alert.acknowledged.is_(True), Alert.resolved.is_(False))
        elif status == "resolved":
            stmt = stmt.where(Alert.resolved.is_(True))
        elif status == "false_positive":
            stmt = stmt.where(Alert.false_positive.is_(True))
        elif status == "new":
            stmt = stmt.where(Alert.acknowledged.is_(False), Alert.resolved.is_(False))

        return stmt

    def list(
        self,
        page: int,
        page_size: int,
        severity: str | None = None,
        status: str | None = None,
        camera_id: int | None = None,
        date_from: datetime | None = None,
        date_to: datetime | None = None,
        search: str | None = None,
        sort_by: str = "created_at",
        sort_dir: str = "desc",
    ) -> tuple[list[Alert], int]:
        stmt = self._base_query(severity, status, camera_id, date_from, date_to, search)

        total = self.db.scalar(select(func.count()).select_from(stmt.subquery()))

        sort_col = SORTABLE_FIELDS.get(sort_by, Alert.created_at)
        stmt = stmt.order_by(sort_col.desc() if sort_dir == "desc" else sort_col.asc())
        stmt = stmt.offset((page - 1) * page_size).limit(page_size)

        rows = list(self.db.execute(stmt).unique().scalars())
        return rows, total or 0

    def get(self, alert_id: int) -> Alert | None:
        stmt = select(Alert).options(joinedload(Alert.camera)).where(Alert.id == alert_id)
        return self.db.execute(stmt).unique().scalar_one_or_none()

    def create(
        self, type_: str, severity: str, camera_id: int | None, confidence: float | None,
        experimental: bool, lat: float | None, lng: float | None,
        snapshot: str | None, clip: str | None, details: dict,
    ) -> Alert:
        alert = Alert(
            type=type_, severity=severity, camera_id=camera_id, confidence=confidence,
            experimental=experimental, lat=lat, lng=lng, snapshot=snapshot, clip=clip,
            details=json.dumps(details or {}),
        )
        self.db.add(alert)
        self.db.commit()
        self.db.refresh(alert)
        return self.get(alert.id)

    def acknowledge(self, alert: Alert) -> Alert:
        alert.acknowledged = True
        self.db.commit()
        self.db.refresh(alert)
        return alert

    def resolve(self, alert: Alert) -> Alert:
        alert.resolved = True
        alert.acknowledged = True
        self.db.commit()
        self.db.refresh(alert)
        return alert

    def flag_false_positive(self, alert: Alert, value: bool) -> Alert:
        alert.false_positive = value
        self.db.commit()
        self.db.refresh(alert)
        return alert

    def delete(self, alert: Alert) -> None:
        self.db.delete(alert)
        self.db.commit()
