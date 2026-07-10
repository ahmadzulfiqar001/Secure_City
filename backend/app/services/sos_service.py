from sqlalchemy import select
from sqlalchemy.orm import Session

from ..core.errors import NotFoundError
from ..core.ws_events import NOTIFICATION_NEW, SOS_TRIGGERED, STAFF_ROLES
from ..core.ws_manager import manager
from ..models import Role, SOSEvent, User
from ..repositories.audit_log_repository import AuditLogRepository
from ..repositories.notification_repository import NotificationRepository
from ..repositories.sos_repository import SOSRepository
from ..schemas.sos import SOSOut


class SOSService:
    def __init__(self, db: Session):
        self.db = db
        self.sos = SOSRepository(db)
        self.audit = AuditLogRepository(db)
        self.notifications = NotificationRepository(db)

    def _staff_user_ids(self) -> list[int]:
        stmt = select(User.id).join(Role, User.role_id == Role.id).where(Role.name.in_(STAFF_ROLES))
        return list(self.db.execute(stmt).scalars())

    def create(self, user_id: int, lat: float, lng: float, alert_id: int | None, ip: str | None) -> SOSEvent:
        event = self.sos.create(user_id, lat, lng, alert_id)
        self.audit.log("sos_create", user_id=user_id, resource_type="sos_event", resource_id=str(event.id), ip_address=ip)

        payload = SOSOut.model_validate(event).model_dump(mode="json")
        manager.broadcast_sync(SOS_TRIGGERED, payload, roles=STAFF_ROLES)

        for staff_id in self._staff_user_ids():
            note = self.notifications.create(
                staff_id, "SOS Triggered", f"SOS event #{event.id} triggered — respond immediately.", "safety"
            )
            manager.send_to_user_sync(staff_id, NOTIFICATION_NEW, {
                "id": note.id, "title": note.title, "body": note.body, "type": note.type, "read": note.read,
            })
        return event

    def list(self, user_id: int, page: int, page_size: int) -> tuple[list[SOSEvent], int]:
        return self.sos.list(user_id, page, page_size)

    def get(self, user_id: int, event_id: int) -> SOSEvent:
        event = self.sos.get(user_id, event_id)
        if not event:
            raise NotFoundError("SOS event not found")
        return event
