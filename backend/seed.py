"""Seeds demo data: roles/permissions, an admin user, 6 real Lahore/Karachi
cameras, and a handful of sample alerts.

Run with:  python seed.py

Idempotent — safe to run more than once; it skips anything that's already
there instead of duplicating rows.
"""
import json
import logging
from datetime import datetime, timedelta, timezone

from app.core.db import SessionLocal
from app.core.logging import configure_logging
from app.core.security import hash_password
from app.models import Alert, Camera, Permission, Role, User

configure_logging()
log = logging.getLogger("securecity.seed")

ROLES = {
    "admin": [
        "alerts:read", "alerts:write", "alerts:delete",
        "cameras:read", "cameras:manage",
        "incidents:read", "incidents:manage",
        "users:read", "users:manage",
    ],
    "operator": ["alerts:read", "alerts:write", "cameras:read", "incidents:read", "incidents:manage"],
    "citizen": ["alerts:read", "cameras:read"],
}

# Real Lahore/Karachi landmarks — matches the mobile app's/ai_engine's camera list.
CAMERAS = [
    ("CAM-01", "Mall Road, Lahore", 31.5497, 74.3436),
    ("CAM-02", "Liberty Market, Lahore", 31.5085, 74.3436),
    ("CAM-03", "Data Darbar, Lahore", 31.5925, 74.3105),
    ("CAM-04", "Saddar Town, Karachi", 24.8608, 67.0104),
    ("CAM-05", "Clifton Beach, Karachi", 24.8138, 67.0299),
    ("CAM-06", "I.I. Chundrigar Road, Karachi", 24.8500, 66.9891),
]

# Demo restricted zone for CAM-01 — a corner of the frame, fractional
# (0-1) top-left-origin coordinates, the same convention ai_engine's
# supervision.PolygonZone consumes.
DEMO_ZONE = [[0.0, 0.0], [0.28, 0.0], [0.28, 0.35], [0.0, 0.35]]

SAMPLE_ALERTS = [
    # (camera_code, type, severity, confidence, experimental, minutes_ago, acknowledged, resolved)
    ("CAM-01", "Weapon Detected", "critical", 0.87, True, 12, False, False),
    ("CAM-02", "Overcrowding", "medium", 0.91, False, 40, True, False),
    ("CAM-03", "Fight Detected", "critical", 0.62, True, 65, True, True),
    ("CAM-04", "Restricted Area Intrusion", "medium", 0.90, False, 90, False, False),
    ("CAM-05", "Suspicious Loitering", "low", 0.65, False, 130, False, False),
    ("CAM-06", "Fire Detected", "critical", 0.99, True, 180, True, True),
]


def get_or_create_role(db, name: str, perms: dict[str, Permission]) -> Role:
    """Creates the role if missing, and — since ROLES is a living spec, not
    a one-time snapshot — always re-syncs its permission set, so re-running
    seed.py after ROLES changes actually updates existing roles instead of
    silently leaving them stale."""
    role = db.query(Role).filter_by(name=name).first()
    wanted = [perms[p] for p in ROLES[name]]
    if role:
        if {p.name for p in role.permissions} != set(ROLES[name]):
            role.permissions = wanted
            db.flush()
            log.info("synced permissions for role %s", name)
        return role
    role = Role(name=name, description=f"{name.title()} role", permissions=wanted)
    db.add(role)
    db.flush()
    log.info("created role %s", name)
    return role


def seed_roles_and_permissions(db) -> dict[str, Role]:
    all_perm_names = sorted({p for perms in ROLES.values() for p in perms})
    perms: dict[str, Permission] = {}
    for name in all_perm_names:
        perm = db.query(Permission).filter_by(name=name).first()
        if not perm:
            perm = Permission(name=name, description=name.replace(":", " ").title())
            db.add(perm)
            db.flush()
        perms[name] = perm

    roles = {name: get_or_create_role(db, name, perms) for name in ROLES}
    db.commit()
    return roles


def seed_admin_user(db, admin_role: Role) -> User:
    user = db.query(User).filter_by(email="admin@securecity.pk").first()
    if user:
        return user
    user = User(
        name="System Administrator",
        email="admin@securecity.pk",
        phone="+923000000000",
        password_hash=hash_password("ChangeMe123!"),
        is_verified=True,
        role=admin_role,
    )
    db.add(user)
    db.commit()
    log.info("created admin user admin@securecity.pk / ChangeMe123! (CHANGE THIS PASSWORD)")
    return user


def seed_cameras(db) -> dict[str, Camera]:
    cameras: dict[str, Camera] = {}
    for code, name, lat, lng in CAMERAS:
        cam = db.query(Camera).filter_by(code=code).first()
        if not cam:
            zone = json.dumps(DEMO_ZONE) if code == "CAM-01" else None
            cam = Camera(code=code, name=name, lat=lat, lng=lng, status="online", zone=zone)
            db.add(cam)
            db.flush()
            log.info("created camera %s (%s)", code, name)
        cameras[code] = cam
    db.commit()
    return cameras


def seed_alerts(db, cameras: dict[str, Camera]) -> None:
    if db.query(Alert).count() > 0:
        log.info("alerts already seeded, skipping")
        return
    now = datetime.now(timezone.utc)
    for code, type_, severity, confidence, experimental, mins_ago, acked, resolved in SAMPLE_ALERTS:
        cam = cameras[code]
        db.add(Alert(
            type=type_,
            severity=severity,
            confidence=confidence,
            experimental=experimental,
            camera_id=cam.id,
            lat=cam.lat,
            lng=cam.lng,
            details='{"demo": true}',
            acknowledged=acked,
            resolved=resolved,
            created_at=now - timedelta(minutes=mins_ago),
        ))
    db.commit()
    log.info("seeded %d sample alerts", len(SAMPLE_ALERTS))


def main() -> None:
    db = SessionLocal()
    try:
        roles = seed_roles_and_permissions(db)
        seed_admin_user(db, roles["admin"])
        cameras = seed_cameras(db)
        seed_alerts(db, cameras)
        log.info("seed complete")
    finally:
        db.close()


if __name__ == "__main__":
    main()
