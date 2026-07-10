from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..core.security import utcnow
from ..models import RefreshToken


class RefreshTokenRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, user_id: int, token_hash: str, expires_at: datetime) -> RefreshToken:
        row = RefreshToken(user_id=user_id, token_hash=token_hash, expires_at=expires_at)
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return row

    def get_valid(self, token_hash: str) -> RefreshToken | None:
        stmt = select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        row = self.db.execute(stmt).scalar_one_or_none()
        if row is None or row.revoked or row.expires_at < utcnow():
            return None
        return row

    def revoke(self, row: RefreshToken) -> None:
        row.revoked = True
        self.db.commit()

    def revoke_all_for_user(self, user_id: int) -> None:
        stmt = select(RefreshToken).where(RefreshToken.user_id == user_id, RefreshToken.revoked.is_(False))
        for row in self.db.execute(stmt).scalars():
            row.revoked = True
        self.db.commit()
