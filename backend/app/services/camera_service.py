from __future__ import annotations

from sqlalchemy.orm import Session

from ..core.errors import ConflictError, NotFoundError
from ..core.ws_events import ALL_ROLES, CAMERA_STATUS
from ..core.ws_manager import manager
from ..models import Camera
from ..repositories.audit_log_repository import AuditLogRepository
from ..repositories.camera_repository import CameraRepository


class CameraService:
    def __init__(self, db: Session):
        self.cameras = CameraRepository(db)
        self.audit = AuditLogRepository(db)

    def list(self, status: str | None) -> list[Camera]:
        return self.cameras.list(status)

    def get(self, camera_id: int) -> Camera:
        cam = self.cameras.get(camera_id)
        if not cam:
            raise NotFoundError("Camera not found")
        return cam

    def create(self, code: str, name: str, lat: float, lng: float, source: str | None,
               status: str, user_id: int, ip: str | None, zone: list | None = None) -> Camera:
        if self.cameras.get_by_code(code):
            raise ConflictError(f"A camera with code '{code}' already exists")
        cam = self.cameras.create(code, name, lat, lng, source, status, zone)
        self.audit.log("camera_create", user_id=user_id, resource_type="camera", resource_id=str(cam.id), ip_address=ip)
        return cam

    def update(self, camera_id: int, name: str, lat: float, lng: float, source: str | None,
               status: str, user_id: int, ip: str | None, zone: list | None = None) -> Camera:
        cam = self.get(camera_id)
        status_changed = cam.status != status
        cam = self.cameras.update(cam, name, lat, lng, source, status, zone)
        self.audit.log("camera_update", user_id=user_id, resource_type="camera", resource_id=str(cam.id), ip_address=ip)
        if status_changed:
            manager.broadcast_sync(CAMERA_STATUS, {"id": cam.id, "code": cam.code, "status": cam.status}, roles=ALL_ROLES)
        return cam

    def delete(self, camera_id: int, user_id: int, ip: str | None) -> None:
        cam = self.get(camera_id)
        self.audit.log("camera_delete", user_id=user_id, resource_type="camera", resource_id=str(cam.id), ip_address=ip)
        self.cameras.delete(cam)
