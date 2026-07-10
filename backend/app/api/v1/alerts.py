from datetime import datetime

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from ...core.deps import get_db, require_permission
from ...models import User
from ...schemas.alert import AlertCreate, AlertOut
from ...schemas.common import Envelope, PageMeta, PaginatedEnvelope
from ...services.alert_service import AlertService

router = APIRouter(prefix="/api/v1/alerts", tags=["alerts"])


def _ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.get("", response_model=PaginatedEnvelope[AlertOut])
def list_alerts(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    severity: str | None = Query(None, description="critical|high|medium|low"),
    status: str | None = Query(None, description="new|acknowledged|resolved|false_positive"),
    camera_id: int | None = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    search: str | None = Query(None, description="matches alert type or camera name"),
    sort_by: str = Query("created_at", description="created_at|severity|type"),
    sort_dir: str = Query("desc", description="asc|desc"),
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission("alerts:read", "alerts:write", "alerts:delete")),
):
    rows, total = AlertService(db).list(
        page, page_size, severity=severity, status=status, camera_id=camera_id,
        date_from=date_from, date_to=date_to, search=search, sort_by=sort_by, sort_dir=sort_dir,
    )
    return PaginatedEnvelope(
        data=[AlertOut.from_alert(a) for a in rows],
        meta=PageMeta.build(page, page_size, total),
    )


@router.get("/{alert_id}", response_model=Envelope[AlertOut])
def get_alert(
    alert_id: int, db: Session = Depends(get_db),
    _user: User = Depends(require_permission("alerts:read", "alerts:write", "alerts:delete")),
):
    alert = AlertService(db).get(alert_id)
    return Envelope(data=AlertOut.from_alert(alert))


@router.post("", status_code=201, response_model=Envelope[AlertOut])
def create_alert(
    request: Request, body: AlertCreate, db: Session = Depends(get_db),
    user: User = Depends(require_permission("alerts:write")),
):
    alert = AlertService(db).create(
        body.type, body.severity, body.camera_id, body.confidence, body.experimental,
        body.lat, body.lng, body.snapshot, body.clip, body.details, user.id, _ip(request),
    )
    return Envelope(data=AlertOut.from_alert(alert))


@router.patch("/{alert_id}/acknowledge", response_model=Envelope[AlertOut])
def acknowledge_alert(
    request: Request, alert_id: int, db: Session = Depends(get_db),
    user: User = Depends(require_permission("alerts:write")),
):
    alert = AlertService(db).acknowledge(alert_id, user.id, _ip(request))
    return Envelope(data=AlertOut.from_alert(alert))


@router.patch("/{alert_id}/resolve", response_model=Envelope[AlertOut])
def resolve_alert(
    request: Request, alert_id: int, db: Session = Depends(get_db),
    user: User = Depends(require_permission("alerts:write")),
):
    alert = AlertService(db).resolve(alert_id, user.id, _ip(request))
    return Envelope(data=AlertOut.from_alert(alert))


@router.patch("/{alert_id}/false-positive", response_model=Envelope[AlertOut])
def flag_false_positive(
    request: Request, alert_id: int, value: bool = True, db: Session = Depends(get_db),
    user: User = Depends(require_permission("alerts:write")),
):
    alert = AlertService(db).flag_false_positive(alert_id, value, user.id, _ip(request))
    return Envelope(data=AlertOut.from_alert(alert))


@router.delete("/{alert_id}", response_model=Envelope[dict])
def delete_alert(
    request: Request, alert_id: int, db: Session = Depends(get_db),
    user: User = Depends(require_permission("alerts:delete")),
):
    AlertService(db).delete(alert_id, user.id, _ip(request))
    return Envelope(data={"deleted": True})
