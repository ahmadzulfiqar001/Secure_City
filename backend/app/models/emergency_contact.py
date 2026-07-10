from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..core.db import Base


class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    user: Mapped["User"] = relationship(back_populates="contacts")

    name: Mapped[str] = mapped_column(String(120))
    relation: Mapped[str] = mapped_column(String(60))
    phone: Mapped[str] = mapped_column(String(32))
