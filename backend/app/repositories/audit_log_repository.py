import json

from sqlalchemy.orm import Session

from ..models import AuditLog


class AuditLogRepository:
    def __init__(self, db: Session):
        self.db = db

    def log(
        self,
        action: str,
        user_id: int | None = None,
        resource_type: str | None = None,
        resource_id: str | None = None,
        details: dict | None = None,
        ip_address: str | None = None,
    ) -> None:
        self.db.add(AuditLog(
            user_id=user_id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            details=json.dumps(details or {}),
            ip_address=ip_address,
        ))
        self.db.commit()
