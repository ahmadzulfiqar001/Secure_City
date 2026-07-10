"""Imports every model so they all register on `Base.metadata` — required
for Alembic's autogenerate to see the full schema from one import."""
from ..core.db import Base
from .alert import Alert
from .audit_log import AuditLog
from .camera import Camera
from .detection_log import DetectionLog
from .emergency_contact import EmergencyContact
from .incident import Incident
from .notification import Notification
from .refresh_token import RefreshToken
from .role import Permission, Role, role_permissions
from .setting import Setting
from .sos_event import SOSEvent
from .user import User

__all__ = [
    "Base",
    "Alert",
    "AuditLog",
    "Camera",
    "DetectionLog",
    "EmergencyContact",
    "Incident",
    "Notification",
    "Permission",
    "RefreshToken",
    "Role",
    "role_permissions",
    "Setting",
    "SOSEvent",
    "User",
]
