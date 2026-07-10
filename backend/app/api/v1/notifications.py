from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ...core.deps import get_current_user, get_db
from ...models import User
from ...schemas.common import Envelope, PageMeta, PaginatedEnvelope
from ...schemas.notification import NotificationOut, UnreadCountOut
from ...services.notification_service import NotificationService

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


@router.get("", response_model=PaginatedEnvelope[NotificationOut])
def list_notifications(
    page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100), unread_only: bool = False,
    user: User = Depends(get_current_user), db: Session = Depends(get_db),
):
    rows, total = NotificationService(db).list(user.id, page, page_size, unread_only)
    return PaginatedEnvelope(
        data=[NotificationOut.model_validate(n) for n in rows], meta=PageMeta.build(page, page_size, total)
    )


@router.get("/unread-count", response_model=Envelope[UnreadCountOut])
def unread_count(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    count = NotificationService(db).unread_count(user.id)
    return Envelope(data=UnreadCountOut(unread=count))


@router.patch("/{notification_id}/read", response_model=Envelope[NotificationOut])
def mark_read(notification_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    n = NotificationService(db).mark_read(user.id, notification_id)
    return Envelope(data=NotificationOut.model_validate(n))


@router.patch("/mark-all-read", response_model=Envelope[dict])
def mark_all_read(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    count = NotificationService(db).mark_all_read(user.id)
    return Envelope(data={"marked": count})


@router.delete("/{notification_id}", response_model=Envelope[dict])
def delete_notification(notification_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    NotificationService(db).delete(user.id, notification_id)
    return Envelope(data={"deleted": True})
