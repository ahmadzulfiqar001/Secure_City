from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..models import EmergencyContact


class ContactRepository:
    def __init__(self, db: Session):
        self.db = db

    def list(self, user_id: int) -> list[EmergencyContact]:
        stmt = select(EmergencyContact).where(EmergencyContact.user_id == user_id).order_by(EmergencyContact.id)
        return list(self.db.execute(stmt).scalars())

    def count(self, user_id: int) -> int:
        stmt = select(func.count()).select_from(EmergencyContact).where(EmergencyContact.user_id == user_id)
        return self.db.scalar(stmt) or 0

    def get(self, user_id: int, contact_id: int) -> EmergencyContact | None:
        stmt = select(EmergencyContact).where(EmergencyContact.id == contact_id, EmergencyContact.user_id == user_id)
        return self.db.execute(stmt).scalar_one_or_none()

    def create(self, user_id: int, name: str, relation: str, phone: str) -> EmergencyContact:
        contact = EmergencyContact(user_id=user_id, name=name, relation=relation, phone=phone)
        self.db.add(contact)
        self.db.commit()
        self.db.refresh(contact)
        return contact

    def update(self, contact: EmergencyContact, name: str, relation: str, phone: str) -> EmergencyContact:
        contact.name, contact.relation, contact.phone = name, relation, phone
        self.db.commit()
        self.db.refresh(contact)
        return contact

    def delete(self, contact: EmergencyContact) -> None:
        self.db.delete(contact)
        self.db.commit()
