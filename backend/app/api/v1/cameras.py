from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from ...core.deps import get_db, require_permission
from ...models import User
from ...schemas.camera import CameraCreate, CameraOut, CameraUpdate
from ...schemas.common import Envelope
from ...services.camera_service import CameraService

router = APIRouter(prefix="/api/v1/cameras", tags=["cameras"])


def _ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.get("", response_model=Envelope[list[CameraOut]])
def list_cameras(
    status: str | None = None,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission("cameras:read", "cameras:manage")),
):
    cams = CameraService(db).list(status)
    return Envelope(data=[CameraOut.from_camera(c) for c in cams])


@router.get("/{camera_id}", response_model=Envelope[CameraOut])
def get_camera(
    camera_id: int, db: Session = Depends(get_db),
    _user: User = Depends(require_permission("cameras:read", "cameras:manage")),
):
    cam = CameraService(db).get(camera_id)
    return Envelope(data=CameraOut.from_camera(cam))


@router.post("", status_code=201, response_model=Envelope[CameraOut])
def create_camera(
    request: Request, body: CameraCreate, db: Session = Depends(get_db),
    user: User = Depends(require_permission("cameras:manage")),
):
    cam = CameraService(db).create(
        body.code, body.name, body.lat, body.lng, body.source, body.status, user.id, _ip(request), body.zone
    )
    return Envelope(data=CameraOut.from_camera(cam))


@router.put("/{camera_id}", response_model=Envelope[CameraOut])
def update_camera(
    request: Request, camera_id: int, body: CameraUpdate, db: Session = Depends(get_db),
    user: User = Depends(require_permission("cameras:manage")),
):
    cam = CameraService(db).update(
        camera_id, body.name, body.lat, body.lng, body.source, body.status, user.id, _ip(request), body.zone
    )
    return Envelope(data=CameraOut.from_camera(cam))


@router.delete("/{camera_id}", response_model=Envelope[dict])
def delete_camera(
    request: Request, camera_id: int, db: Session = Depends(get_db),
    user: User = Depends(require_permission("cameras:manage")),
):
    CameraService(db).delete(camera_id, user.id, _ip(request))
    return Envelope(data={"deleted": True})
