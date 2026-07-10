from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..models import SOSEvent


class SOSRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, user_id: int, lat: float, lng: float, alert_id: int | None) -> SOSEvent:
        event = SOSEvent(user_id=user_id, lat=lat, lng=lng, alert_id=alert_id, status="active")
        self.db.add(event)
        self.db.commit()
        self.db.refresh(event)
        return event

    def list(self, user_id: int, page: int, page_size: int) -> tuple[list[SOSEvent], int]:
        stmt = select(SOSEvent).where(SOSEvent.user_id == user_id)
        total = self.db.scalar(select(func.count()).select_from(stmt.subquery()))
        stmt = stmt.order_by(SOSEvent.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        rows = list(self.db.execute(stmt).scalars())
        return rows, total or 0

    def get(self, user_id: int, event_id: int) -> SOSEvent | None:
        stmt = select(SOSEvent).where(SOSEvent.id == event_id, SOSEvent.user_id == user_id)
        return self.db.execute(stmt).scalar_one_or_none()
