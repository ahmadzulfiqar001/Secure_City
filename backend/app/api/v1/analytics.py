from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.deps import get_db, require_permission
from ...models import User
from ...schemas.analytics import AnalyticsOverviewOut
from ...schemas.common import Envelope
from ...services.analytics_service import AnalyticsService

router = APIRouter(prefix="/api/v1/analytics", tags=["analytics"])


@router.get("/overview", response_model=Envelope[AnalyticsOverviewOut])
def overview(
    db: Session = Depends(get_db),
    _user: User = Depends(require_permission("alerts:read", "incidents:read", "cameras:read")),
):
    return Envelope(data=AnalyticsService(db).overview())
