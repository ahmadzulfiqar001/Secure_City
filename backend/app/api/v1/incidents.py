from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from ...core.deps import get_db, require_permission
from ...models import User
from ...schemas.common import Envelope, PageMeta, PaginatedEnvelope
from ...schemas.incident import IncidentCreate, IncidentOut, IncidentUpdate
from ...services.incident_service import IncidentService

router = APIRouter(prefix="/api/v1/incidents", tags=["incidents"])


def _ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.get("", response_model=PaginatedEnvelope[IncidentOut])
def list_incidents(
    page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100),
    status: str | None = None, severity: str | None = None,
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission("incidents:read", "incidents:manage")),
):
    rows, total = IncidentService(db).list(page, page_size, status, severity)
    return PaginatedEnvelope(data=[IncidentOut.from_incident(i) for i in rows], meta=PageMeta.build(page, page_size, total))


@router.get("/{incident_id}", response_model=Envelope[IncidentOut])
def get_incident(
    incident_id: int, db: Session = Depends(get_db),
    _user: User = Depends(require_permission("incidents:read", "incidents:manage")),
):
    incident = IncidentService(db).get(incident_id)
    return Envelope(data=IncidentOut.from_incident(incident))


@router.post("", status_code=201, response_model=Envelope[IncidentOut])
def create_incident(
    request: Request, body: IncidentCreate, db: Session = Depends(get_db),
    user: User = Depends(require_permission("incidents:manage")),
):
    incident = IncidentService(db).create(
        body.title, body.description, body.severity, body.camera_id, body.alert_ids, user.id, _ip(request)
    )
    return Envelope(data=IncidentOut.from_incident(incident))


@router.put("/{incident_id}", response_model=Envelope[IncidentOut])
def update_incident(
    request: Request, incident_id: int, body: IncidentUpdate, db: Session = Depends(get_db),
    user: User = Depends(require_permission("incidents:manage")),
):
    incident = IncidentService(db).update(
        incident_id, body.title, body.description, body.status, body.severity, body.alert_ids, user.id, _ip(request)
    )
    return Envelope(data=IncidentOut.from_incident(incident))


@router.delete("/{incident_id}", response_model=Envelope[dict])
def delete_incident(
    request: Request, incident_id: int, db: Session = Depends(get_db),
    user: User = Depends(require_permission("incidents:manage")),
):
    IncidentService(db).delete(incident_id, user.id, _ip(request))
    return Envelope(data={"deleted": True})
