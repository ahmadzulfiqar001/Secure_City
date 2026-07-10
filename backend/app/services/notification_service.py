from sqlalchemy.orm import Session

from ..core.errors import NotFoundError
from ..models import Notification
from ..repositories.notification_repository import NotificationRepository


class NotificationService:
    def __init__(self, db: Session):
        self.notifications = NotificationRepository(db)

    def list(self, user_id: int, page: int, page_size: int, unread_only: bool) -> tuple[list[Notification], int]:
        return self.notifications.list(user_id, page, page_size, unread_only)

    def unread_count(self, user_id: int) -> int:
        return self.notifications.unread_count(user_id)

    def mark_read(self, user_id: int, notification_id: int) -> Notification:
        n = self.notifications.get(user_id, notification_id)
        if not n:
            raise NotFoundError("Notification not found")
        return self.notifications.mark_read(n)

    def mark_all_read(self, user_id: int) -> int:
        return self.notifications.mark_all_read(user_id)

    def delete(self, user_id: int, notification_id: int) -> None:
        n = self.notifications.get(user_id, notification_id)
        if not n:
            raise NotFoundError("Notification not found")
        self.notifications.delete(n)
