from __future__ import annotations

import json

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Camera


class CameraRepository:
    def __init__(self, db: Session):
        self.db = db

    def list(self, status: str | None = None) -> list[Camera]:
        stmt = select(Camera)
        if status:
            stmt = stmt.where(Camera.status == status)
        stmt = stmt.order_by(Camera.code)
        return list(self.db.execute(stmt).scalars())

    def get(self, camera_id: int) -> Camera | None:
        return self.db.get(Camera, camera_id)

    def get_by_code(self, code: str) -> Camera | None:
        stmt = select(Camera).where(Camera.code == code)
        return self.db.execute(stmt).scalar_one_or_none()

    def create(
        self, code: str, name: str, lat: float, lng: float, source: str | None,
        status: str, zone: list | None = None,
    ) -> Camera:
        cam = Camera(code=code, name=name, lat=lat, lng=lng, source=source, status=status, zone=json.dumps(zone) if zone else None)
        self.db.add(cam)
        self.db.commit()
        self.db.refresh(cam)
        return cam

    def update(
        self, cam: Camera, name: str, lat: float, lng: float, source: str | None,
        status: str, zone: list | None = None,
    ) -> Camera:
        cam.name, cam.lat, cam.lng, cam.source, cam.status = name, lat, lng, source, status
        cam.zone = json.dumps(zone) if zone else None
        self.db.commit()
        self.db.refresh(cam)
        return cam

    def delete(self, cam: Camera) -> None:
        self.db.delete(cam)
        self.db.commit()
