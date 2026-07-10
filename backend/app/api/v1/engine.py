"""Ingest API for the ai_engine worker process — gated by a shared secret
(X-Engine-Key) instead of a user JWT, since there's no human user behind
these requests. This is the only HTTP boundary the AI engine crosses to
reach the backend; it never touches the database directly.
"""
import json
import os
import uuid

from fastapi import APIRouter, Depends, File, Form, UploadFile
from sqlalchemy.orm import Session

from ...core.config import settings
from ...core.db import get_db
from ...core.deps import require_engine_key
from ...core.errors import NotFoundError
from ...repositories.camera_repository import CameraRepository
from ...repositories.detection_log_repository import DetectionLogRepository
from ...schemas.alert import AlertOut
from ...schemas.common import Envelope
from ...schemas.engine import DetectionBatchIn, EngineCameraOut
from ...services.alert_service import AlertService

router = APIRouter(prefix="/api/v1/engine", tags=["engine"], dependencies=[Depends(require_engine_key)])

EVIDENCE_DIR = settings.static_dir / "evidence"
EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)


def _save_evidence(upload: UploadFile, content: bytes) -> str:
    ext = os.path.splitext(upload.filename or "")[1] or ".bin"
    name = f"{uuid.uuid4().hex}{ext}"
    with open(EVIDENCE_DIR / name, "wb") as f:
        f.write(content)
    return f"/static/evidence/{name}"


@router.get("/cameras/{code}", response_model=Envelope[EngineCameraOut])
def get_camera_config(code: str, db: Session = Depends(get_db)):
    cam = CameraRepository(db).get_by_code(code)
    if not cam:
        raise NotFoundError(f"No camera with code '{code}'")
    zone = json.loads(cam.zone) if cam.zone else None
    return Envelope(data=EngineCameraOut(
        id=cam.id, code=cam.code, name=cam.name, lat=cam.lat, lng=cam.lng,
        source=cam.source, status=cam.status, zone=zone,
    ))


@router.post("/alerts", status_code=201, response_model=Envelope[AlertOut])
async def ingest_alert(
    type: str = Form(...),
    severity: str = Form(...),
    camera_code: str = Form(...),
    confidence: float | None = Form(None),
    experimental: bool = Form(False),
    details: str = Form("{}"),
    snapshot: UploadFile = File(...),
    clip: UploadFile | None = File(None),
    db: Session = Depends(get_db),
):
    cam = CameraRepository(db).get_by_code(camera_code)
    if not cam:
        raise NotFoundError(f"No camera with code '{camera_code}'")

    try:
        parsed_details = json.loads(details)
    except json.JSONDecodeError:
        parsed_details = {}

    snapshot_url = _save_evidence(snapshot, await snapshot.read())
    clip_url = _save_evidence(clip, await clip.read()) if clip is not None else None

    alert = AlertService(db).create(
        type, severity, cam.id, confidence, experimental, cam.lat, cam.lng,
        snapshot_url, clip_url, parsed_details, user_id=None, ip="ai-engine",
    )
    return Envelope(data=AlertOut.from_alert(alert))


@router.post("/detections", status_code=201, response_model=Envelope[dict])
def ingest_detections(body: DetectionBatchIn, db: Session = Depends(get_db)):
    """Raw per-frame detection log — feeds future accuracy/false-positive
    analytics (DetectionLog), separate from confirmed Alerts. Best-effort
    on the ai_engine side (see publisher.publish_detections): a dropped or
    rejected batch never interrupts the detection loop."""
    cam = CameraRepository(db).get_by_code(body.camera_code)
    if not cam:
        raise NotFoundError(f"No camera with code '{body.camera_code}'")
    count = DetectionLogRepository(db).bulk_create(cam.id, [d.model_dump() for d in body.detections])
    return Envelope(data={"created": count})
