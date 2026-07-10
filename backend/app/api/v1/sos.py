from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from ...core.deps import get_current_user, get_db
from ...models import User
from ...schemas.common import Envelope, PageMeta, PaginatedEnvelope
from ...schemas.sos import SOSCreate, SOSOut
from ...services.sos_service import SOSService

router = APIRouter(prefix="/api/v1/sos", tags=["sos"])


def _ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


@router.post("", status_code=201, response_model=Envelope[SOSOut])
def create_sos(
    request: Request, body: SOSCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    event = SOSService(db).create(user.id, body.lat, body.lng, body.alert_id, _ip(request))
    return Envelope(data=SOSOut.model_validate(event))


@router.get("", response_model=PaginatedEnvelope[SOSOut])
def list_sos(
    page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100),
    user: User = Depends(get_current_user), db: Session = Depends(get_db),
):
    rows, total = SOSService(db).list(user.id, page, page_size)
    return PaginatedEnvelope(data=[SOSOut.model_validate(e) for e in rows], meta=PageMeta.build(page, page_size, total))


@router.get("/{event_id}", response_model=Envelope[SOSOut])
def get_sos(event_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    event = SOSService(db).get(user.id, event_id)
    return Envelope(data=SOSOut.model_validate(event))
