"""SecureCity backend — FastAPI app.

Serves the REST API consumed by the Flutter app, the MJPEG live stream,
a WebSocket alert feed, and the admin monitoring dashboard (Module 5).
"""
import asyncio
import random
import shutil
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

from fastapi import Depends, FastAPI, HTTPException, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, field_validator

from . import config, database, security
from .detection.engine import engine

app = FastAPI(title="SecureCity Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup() -> None:
    database.init_db()
    engine.start()


# ── auth ─────────────────────────────────────────────────────────────
# NOTE ON OTP DELIVERY: there is no SMS/email gateway configured for this
# prototype, so OTP codes are returned in the API response (`otp_debug`) and
# printed to the server log instead of actually being texted/emailed. Wire a
# real provider (Twilio, SendGrid, ...) into `_send_otp` when one is
# available; nothing else about the verification flow needs to change.
OTP_TTL_MINUTES = 10


def _public_user(user: dict) -> dict:
    return {
        "id": user["id"],
        "name": user["name"],
        "email": user["email"],
        "phone": user["phone"],
        "verified": bool(user["verified"]),
    }


def _send_otp(user: dict, purpose: str) -> str:
    code = f"{random.randint(0, 999999):06d}"
    expires = (datetime.now(timezone.utc) + timedelta(minutes=OTP_TTL_MINUTES)).isoformat()
    database.set_otp(user["id"], code, purpose, expires)
    print(f"[DEV OTP] {purpose} code for {user['email']}: {code} (expires in {OTP_TTL_MINUTES} min)")
    return code


def _check_otp(user: dict, code: str, purpose: str) -> None:
    if not user["otp_code"] or user["otp_purpose"] != purpose:
        raise HTTPException(status_code=400, detail="No pending verification for this account")
    if datetime.now(timezone.utc) > datetime.fromisoformat(user["otp_expires"]):
        raise HTTPException(status_code=400, detail="This code has expired. Request a new one.")
    if code.strip() != user["otp_code"]:
        raise HTTPException(status_code=400, detail="Incorrect code")


class RegisterBody(BaseModel):
    name: str
    email: str
    phone: str
    password: str

    @field_validator("email")
    @classmethod
    def _valid_email(cls, v: str) -> str:
        if "@" not in v or "." not in v.split("@")[-1]:
            raise ValueError("Enter a valid email address")
        return v

    @field_validator("password")
    @classmethod
    def _valid_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters")
        return v


class LoginBody(BaseModel):
    email: str
    password: str


class OtpBody(BaseModel):
    email: str
    code: str


class EmailBody(BaseModel):
    email: str


class ResetPasswordBody(BaseModel):
    email: str
    code: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _valid_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters")
        return v


class ChangePasswordBody(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _valid_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters")
        return v


class UpdateProfileBody(BaseModel):
    name: str
    phone: str


def _get_user_or_404(email: str) -> dict:
    user = database.get_user_by_email(email)
    if not user:
        raise HTTPException(status_code=404, detail="No account with this email")
    return user


@app.post("/api/auth/register", status_code=201)
def register(body: RegisterBody):
    if database.get_user_by_email(body.email):
        raise HTTPException(status_code=409, detail="An account with this email already exists")
    user = database.create_user(
        body.name.strip(), body.email, body.phone.strip(), security.hash_password(body.password)
    )
    otp = _send_otp(user, "verify")
    return {
        "user": _public_user(user),
        "otp_debug": otp,
        "message": "Verify your account with the code we generated (see otp_debug — no SMS gateway configured yet).",
    }


@app.post("/api/auth/verify-otp")
def verify_otp(body: OtpBody):
    user = _get_user_or_404(body.email)
    _check_otp(user, body.code, "verify")
    database.mark_verified(user["id"])
    database.clear_otp(user["id"])
    user = database.get_user_by_id(user["id"])
    token = security.create_access_token(user["id"], user["email"])
    return {"token": token, "user": _public_user(user)}


@app.post("/api/auth/resend-otp")
def resend_otp(body: EmailBody):
    user = _get_user_or_404(body.email)
    purpose = "reset" if user["verified"] else "verify"
    otp = _send_otp(user, purpose)
    return {"otp_debug": otp, "message": "A new code was generated (see otp_debug)."}


@app.post("/api/auth/login")
def login(body: LoginBody):
    user = database.get_user_by_email(body.email)
    if not user or not security.verify_password(body.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    token = security.create_access_token(user["id"], user["email"])
    return {"token": token, "user": _public_user(user)}


@app.post("/api/auth/forgot-password")
def forgot_password(body: EmailBody):
    user = _get_user_or_404(body.email)
    otp = _send_otp(user, "reset")
    return {"otp_debug": otp, "message": "Use this code to reset your password (see otp_debug)."}


@app.post("/api/auth/reset-password")
def reset_password(body: ResetPasswordBody):
    user = _get_user_or_404(body.email)
    _check_otp(user, body.code, "reset")
    database.update_password(user["id"], security.hash_password(body.new_password))
    database.clear_otp(user["id"])
    return {"ok": True}


@app.get("/api/auth/me")
def me(user_id: int = Depends(security.get_current_user_id)):
    user = database.get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _public_user(user)


@app.put("/api/auth/me")
def update_me(body: UpdateProfileBody, user_id: int = Depends(security.get_current_user_id)):
    user = database.update_profile(user_id, body.name.strip(), body.phone.strip())
    return _public_user(user)


@app.post("/api/auth/change-password")
def change_password(body: ChangePasswordBody, user_id: int = Depends(security.get_current_user_id)):
    user = database.get_user_by_id(user_id)
    if not user or not security.verify_password(body.current_password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Current password is incorrect")
    database.update_password(user_id, security.hash_password(body.new_password))
    return {"ok": True}


@app.delete("/api/auth/me")
def delete_me(user_id: int = Depends(security.get_current_user_id)):
    database.delete_user(user_id)
    return {"ok": True}


# ── emergency contacts (Profile API) ─────────────────────────────────
class ContactBody(BaseModel):
    name: str
    relation: str
    phone: str


@app.get("/api/contacts")
def list_contacts(user_id: int = Depends(security.get_current_user_id)):
    return database.get_contacts(user_id)


@app.post("/api/contacts", status_code=201)
def create_contact(body: ContactBody, user_id: int = Depends(security.get_current_user_id)):
    return database.add_contact(user_id, body.name.strip(), body.relation.strip(), body.phone.strip())


@app.delete("/api/contacts/{contact_id}")
def remove_contact(contact_id: int, user_id: int = Depends(security.get_current_user_id)):
    if not database.delete_contact(user_id, contact_id):
        raise HTTPException(status_code=404, detail="Contact not found")
    return {"deleted": True}


# ── safety preferences (Settings API) ────────────────────────────────
@app.get("/api/preferences")
def get_preferences(user_id: int = Depends(security.get_current_user_id)):
    return database.get_preferences(user_id)


@app.put("/api/preferences")
def update_preferences(body: dict[str, bool], user_id: int = Depends(security.get_current_user_id)):
    return database.update_preferences(user_id, body)


# ── REST API ────────────────────────────────────────────────────────
@app.get("/api/health")
def health():
    return {"status": "ok", **engine.status()}


@app.get("/api/stats")
def stats():
    return {**database.get_stats(), **engine.status()}


@app.get("/api/analytics")
def analytics():
    return database.get_analytics()


@app.get("/api/alerts")
def alerts(limit: int = 50, severity: str | None = None, since_id: int | None = None):
    return database.get_alerts(limit=limit, severity=severity, since_id=since_id)


@app.delete("/api/alerts")
def clear_alerts():
    database.clear_alerts()
    return {"cleared": True}


@app.patch("/api/alerts/{alert_id}/acknowledge")
def acknowledge_alert(alert_id: int):
    alert = database.acknowledge_alert(alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    return alert


@app.patch("/api/alerts/{alert_id}/resolve")
def resolve_alert(alert_id: int):
    alert = database.resolve_alert(alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    return alert


@app.delete("/api/alerts/{alert_id}")
def delete_alert(alert_id: int):
    if not database.delete_alert(alert_id):
        raise HTTPException(status_code=404, detail="Alert not found")
    return {"deleted": True}


@app.get("/api/cameras")
def cameras():
    active = engine.camera_id
    return [
        {**cam, "status": "active" if cam["id"] == active else "standby"}
        for cam in config.CAMERAS
    ]


@app.get("/api/snapshots/{name}")
def snapshot(name: str):
    path = (config.SNAPSHOT_DIR / Path(name).name).resolve()
    if not path.is_file():
        raise HTTPException(status_code=404, detail="snapshot not found")
    return FileResponse(path, media_type="image/jpeg")


# ── video source control ────────────────────────────────────────────
class SourceBody(BaseModel):
    source: str          # "0" for webcam, or a video file path
    camera_id: str | None = None


@app.post("/api/source")
def set_source(body: SourceBody):
    if body.camera_id:
        engine.set_camera(body.camera_id)
    engine.set_source(body.source)
    return {"ok": True, **engine.status()}


@app.post("/api/upload")
async def upload_video(file: UploadFile):
    dest = config.VIDEO_DIR / Path(file.filename or "upload.mp4").name
    with dest.open("wb") as f:
        shutil.copyfileobj(file.file, f)
    engine.set_source(str(dest))
    return {"ok": True, "path": str(dest)}


# ── test alert injection (demo without a live camera) ──────────────
DEMO_ALERTS = [
    ("Fight Detected", "high"),
    ("Weapon Detected", "high"),
    ("Panic Movement", "high"),
    ("Overcrowding", "medium"),
    ("Crowd Anomaly", "medium"),
    ("Person Running", "low"),
    ("Suspicious Activity", "low"),
]


@app.post("/api/demo-alert")
def demo_alert():
    type_, severity = random.choice(DEMO_ALERTS)
    camera = random.choice(config.CAMERAS)
    alert = database.insert_alert(
        type_, severity, camera, details={"demo": True}
    )
    return alert


# ── emergency SOS (Flutter app's panic button) ──────────────────────
class SosBody(BaseModel):
    lat: float
    lng: float


@app.post("/api/sos", status_code=201)
def trigger_sos(body: SosBody, user_id: int = Depends(security.get_current_user_id)):
    """Logs a citizen's SOS as a real high-severity alert so it shows up
    immediately in the admin dashboard's live feed and history — the same
    pipeline the AI detection engine writes to, just triggered by a person
    instead of a camera."""
    user = database.get_user_by_id(user_id)
    name = user["name"] if user else "Unknown user"
    camera = {"id": "SOS", "name": f"SOS — {name}", "lat": body.lat, "lng": body.lng}
    alert = database.insert_alert(
        "SOS Triggered",
        "high",
        camera,
        details={"user_id": user_id, "user_name": name, "phone": user["phone"] if user else None},
    )
    return alert


# ── live MJPEG stream ───────────────────────────────────────────────
async def mjpeg_generator():
    boundary = b"--frame\r\nContent-Type: image/jpeg\r\n\r\n"
    while True:
        yield boundary + engine.latest_jpeg() + b"\r\n"
        await asyncio.sleep(0.05)


@app.get("/api/stream")
def stream():
    return StreamingResponse(
        mjpeg_generator(),
        media_type="multipart/x-mixed-replace; boundary=frame",
    )


# ── WebSocket: pushes alerts newer than the client's last seen id ──
@app.websocket("/ws/alerts")
async def ws_alerts(ws: WebSocket):
    await ws.accept()
    latest = database.get_alerts(limit=1)
    last_id = latest[0]["id"] if latest else 0
    try:
        while True:
            new = database.get_alerts(limit=20, since_id=last_id)
            for alert in reversed(new):
                await ws.send_json(alert)
                last_id = max(last_id, alert["id"])
            await asyncio.sleep(1.0)
    except WebSocketDisconnect:
        pass


# ── admin dashboard (static) ────────────────────────────────────────
app.mount("/", StaticFiles(directory=config.ADMIN_DIR, html=True), name="admin")
