from sqlalchemy.orm import Session

from ..core.errors import AppError, NotFoundError
from ..models import EmergencyContact
from ..repositories.contact_repository import ContactRepository

MAX_CONTACTS_PER_USER = 5


class ContactService:
    def __init__(self, db: Session):
        self.contacts = ContactRepository(db)

    def list(self, user_id: int) -> list[EmergencyContact]:
        return self.contacts.list(user_id)

    def create(self, user_id: int, name: str, relation: str, phone: str) -> EmergencyContact:
        if self.contacts.count(user_id) >= MAX_CONTACTS_PER_USER:
            raise AppError(f"Maximum of {MAX_CONTACTS_PER_USER} emergency contacts allowed", status_code=409)
        return self.contacts.create(user_id, name, relation, phone)

    def update(self, user_id: int, contact_id: int, name: str, relation: str, phone: str) -> EmergencyContact:
        contact = self.contacts.get(user_id, contact_id)
        if not contact:
            raise NotFoundError("Emergency contact not found")
        return self.contacts.update(contact, name, relation, phone)

    def delete(self, user_id: int, contact_id: int) -> None:
        contact = self.contacts.get(user_id, contact_id)
        if not contact:
            raise NotFoundError("Emergency contact not found")
        self.contacts.delete(contact)
