from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..models import Notification


class NotificationRepository:
    def __init__(self, db: Session):
        self.db = db

    def list(self, user_id: int, page: int, page_size: int, unread_only: bool) -> tuple[list[Notification], int]:
        stmt = select(Notification).where(Notification.user_id == user_id)
        if unread_only:
            stmt = stmt.where(Notification.read.is_(False))

        total = self.db.scalar(select(func.count()).select_from(stmt.subquery()))
        stmt = stmt.order_by(Notification.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        rows = list(self.db.execute(stmt).scalars())
        return rows, total or 0

    def unread_count(self, user_id: int) -> int:
        stmt = select(func.count()).select_from(Notification).where(
            Notification.user_id == user_id, Notification.read.is_(False)
        )
        return self.db.scalar(stmt) or 0

    def create(self, user_id: int, title: str, body: str, type_: str) -> Notification:
        notification = Notification(user_id=user_id, title=title, body=body, type=type_)
        self.db.add(notification)
        self.db.commit()
        self.db.refresh(notification)
        return notification

    def get(self, user_id: int, notification_id: int) -> Notification | None:
        stmt = select(Notification).where(Notification.id == notification_id, Notification.user_id == user_id)
        return self.db.execute(stmt).scalar_one_or_none()

    def mark_read(self, notification: Notification) -> Notification:
        notification.read = True
        self.db.commit()
        self.db.refresh(notification)
        return notification

    def mark_all_read(self, user_id: int) -> int:
        stmt = select(Notification).where(Notification.user_id == user_id, Notification.read.is_(False))
        rows = list(self.db.execute(stmt).scalars())
        for n in rows:
            n.read = True
        self.db.commit()
        return len(rows)

    def delete(self, notification: Notification) -> None:
        self.db.delete(notification)
        self.db.commit()
