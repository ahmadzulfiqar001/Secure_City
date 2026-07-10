from datetime import datetime

from sqlalchemy.orm import Session

from ..core.errors import NotFoundError
from ..core.ws_events import ALERT_NEW, ALERT_UPDATED, ALL_ROLES
from ..core.ws_manager import manager
from ..models import Alert
from ..repositories.alert_repository import AlertRepository
from ..repositories.audit_log_repository import AuditLogRepository
from ..schemas.alert import AlertOut


class AlertService:
    def __init__(self, db: Session):
        self.alerts = AlertRepository(db)
        self.audit = AuditLogRepository(db)

    def list(self, page: int, page_size: int, **filters) -> tuple[list[Alert], int]:
        return self.alerts.list(page, page_size, **filters)

    def get(self, alert_id: int) -> Alert:
        alert = self.alerts.get(alert_id)
        if not alert:
            raise NotFoundError("Alert not found")
        return alert

    def create(
        self, type_: str, severity: str, camera_id: int | None, confidence: float | None,
        experimental: bool, lat: float | None, lng: float | None, snapshot: str | None,
        clip: str | None, details: dict, user_id: int | None, ip: str | None,
    ) -> Alert:
        alert = self.alerts.create(type_, severity, camera_id, confidence, experimental, lat, lng, snapshot, clip, details)
        self.audit.log("alert_create", user_id=user_id, resource_type="alert", resource_id=str(alert.id), ip_address=ip)
        manager.broadcast_sync(ALERT_NEW, AlertOut.from_alert(alert).model_dump(mode="json"), roles=ALL_ROLES)
        return alert

    def acknowledge(self, alert_id: int, user_id: int, ip: str | None) -> Alert:
        alert = self.get(alert_id)
        alert = self.alerts.acknowledge(alert)
        self.audit.log("alert_acknowledge", user_id=user_id, resource_type="alert", resource_id=str(alert_id), ip_address=ip)
        manager.broadcast_sync(ALERT_UPDATED, AlertOut.from_alert(alert).model_dump(mode="json"), roles=ALL_ROLES)
        return alert

    def resolve(self, alert_id: int, user_id: int, ip: str | None) -> Alert:
        alert = self.get(alert_id)
        alert = self.alerts.resolve(alert)
        self.audit.log("alert_resolve", user_id=user_id, resource_type="alert", resource_id=str(alert_id), ip_address=ip)
        manager.broadcast_sync(ALERT_UPDATED, AlertOut.from_alert(alert).model_dump(mode="json"), roles=ALL_ROLES)
        return alert

    def flag_false_positive(self, alert_id: int, value: bool, user_id: int, ip: str | None) -> Alert:
        alert = self.get(alert_id)
        alert = self.alerts.flag_false_positive(alert, value)
        self.audit.log(
            "alert_false_positive", user_id=user_id, resource_type="alert", resource_id=str(alert_id),
            details={"value": value}, ip_address=ip,
        )
        manager.broadcast_sync(ALERT_UPDATED, AlertOut.from_alert(alert).model_dump(mode="json"), roles=ALL_ROLES)
        return alert

    def delete(self, alert_id: int, user_id: int, ip: str | None) -> None:
        alert = self.get(alert_id)
        self.audit.log("alert_delete", user_id=user_id, resource_type="alert", resource_id=str(alert_id), ip_address=ip)
        self.alerts.delete(alert)
        manager.broadcast_sync(ALERT_UPDATED, {"id": alert_id, "deleted": True}, roles=ALL_ROLES)
