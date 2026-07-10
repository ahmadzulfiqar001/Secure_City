"""Data access for User — the only place that touches the `users` table
directly, so swapping storage later means reimplementing just this class.
"""
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Role, User


class UserRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, user_id: int) -> User | None:
        return self.db.get(User, user_id)

    def get_by_email(self, email: str) -> User | None:
        stmt = select(User).where(User.email == email.lower().strip())
        return self.db.execute(stmt).scalar_one_or_none()

    def get_role(self, name: str) -> Role | None:
        stmt = select(Role).where(Role.name == name)
        return self.db.execute(stmt).scalar_one_or_none()

    def create(self, name: str, email: str, phone: str, password_hash: str, role: Role | None) -> User:
        user = User(
            name=name.strip(), email=email.lower().strip(), phone=phone.strip(),
            password_hash=password_hash, role=role,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def set_otp(self, user: User, code: str, purpose: str, expires_at: datetime) -> None:
        user.otp_code = code
        user.otp_purpose = purpose
        user.otp_expires_at = expires_at
        self.db.commit()

    def clear_otp(self, user: User) -> None:
        user.otp_code = None
        user.otp_purpose = None
        user.otp_expires_at = None
        self.db.commit()

    def mark_verified(self, user: User) -> None:
        user.is_verified = True
        self.db.commit()

    def update_profile(self, user: User, name: str, phone: str) -> User:
        user.name = name.strip()
        user.phone = phone.strip()
        self.db.commit()
        self.db.refresh(user)
        return user

    def update_password(self, user: User, password_hash: str) -> None:
        user.password_hash = password_hash
        self.db.commit()

    def delete(self, user: User) -> None:
        self.db.delete(user)
        self.db.commit()
