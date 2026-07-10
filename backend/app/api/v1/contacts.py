from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ...core.deps import get_current_user, get_db
from ...models import User
from ...schemas.common import Envelope
from ...schemas.contact import ContactCreate, ContactOut, ContactUpdate
from ...services.contact_service import ContactService

router = APIRouter(prefix="/api/v1/contacts", tags=["contacts"])


@router.get("", response_model=Envelope[list[ContactOut]])
def list_contacts(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = ContactService(db).list(user.id)
    return Envelope(data=[ContactOut.model_validate(c) for c in rows])


@router.post("", response_model=Envelope[ContactOut], status_code=201)
def create_contact(body: ContactCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    contact = ContactService(db).create(user.id, body.name, body.relation, body.phone)
    return Envelope(data=ContactOut.model_validate(contact))


@router.put("/{contact_id}", response_model=Envelope[ContactOut])
def update_contact(
    contact_id: int, body: ContactUpdate, user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    contact = ContactService(db).update(user.id, contact_id, body.name, body.relation, body.phone)
    return Envelope(data=ContactOut.model_validate(contact))


@router.delete("/{contact_id}", response_model=Envelope[dict])
def delete_contact(contact_id: int, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    ContactService(db).delete(user.id, contact_id)
    return Envelope(data={"deleted": True})
