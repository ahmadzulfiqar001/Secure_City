"""SecureCity backend — FastAPI app.

Serves the REST API consumed by the Flutter app, the MJPEG live stream,
a WebSocket alert feed, and the admin monitoring dashboard (Module 5).
"""
import asyncio
import random
import shutil
import time
from pathlib import Path

from fastapi import FastAPI, HTTPException, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from . import config, database
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


# ── REST API ────────────────────────────────────────────────────────
@app.get("/api/health")
def health():
    return {"status": "ok", **engine.status()}


@app.get("/api/stats")
def stats():
    return {**database.get_stats(), **engine.status()}


@app.get("/api/alerts")
def alerts(limit: int = 50, severity: str | None = None, since_id: int | None = None):
    return database.get_alerts(limit=limit, severity=severity, since_id=since_id)


@app.delete("/api/alerts")
def clear_alerts():
    database.clear_alerts()
    return {"cleared": True}


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
