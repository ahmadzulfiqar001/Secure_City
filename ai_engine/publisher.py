"""Talks to the backend's engine-key-gated ingest API.

The AI engine is a separate worker process — per A1/A5 it never touches
the database directly. Every alert (with its evidence files) crosses a
real HTTP boundary, secured with a shared secret (`SECURECITY_ENGINE_KEY`)
so the ingest endpoint isn't open to any caller. The backend is then
responsible for persisting it, saving the evidence under /static, and
broadcasting it over WebSocket to the mobile app / admin dashboard.
"""
import json
import logging

import requests

from . import config

log = logging.getLogger("ai_engine.publisher")

_HEADERS = {"X-Engine-Key": config.ENGINE_API_KEY}


def fetch_camera_config(camera_code: str) -> dict | None:
    """Pulls this camera's config (name/lat/lng/source/zone/status) from the
    backend — the single source of truth, per "zones stored in camera
    config". Returns None if the backend is unreachable or the camera code
    doesn't exist there."""
    try:
        res = requests.get(
            f"{config.BACKEND_URL}/api/v1/engine/cameras/{camera_code}",
            headers=_HEADERS, timeout=5,
        )
        if res.status_code != 200:
            log.error("backend rejected camera config lookup for '%s': %s %s", camera_code, res.status_code, res.text[:200])
            return None
        return res.json()["data"]
    except requests.RequestException as e:
        log.error("could not reach backend to fetch camera config for '%s': %s", camera_code, e)
        return None


def publish_alert(
    type_: str,
    severity: str,
    camera_code: str,
    confidence: float | None,
    experimental: bool,
    details: dict,
    snapshot_name: str,
    snapshot_bytes: bytes,
    clip_name: str | None = None,
    clip_bytes: bytes | None = None,
) -> bool:
    data = {
        "type": type_,
        "severity": severity,
        "camera_code": camera_code,
        "experimental": str(experimental),
        "details": json.dumps(details),
    }
    if confidence is not None:
        data["confidence"] = str(confidence)

    files = {"snapshot": (snapshot_name, snapshot_bytes, "image/jpeg")}
    if clip_bytes is not None and clip_name is not None:
        files["clip"] = (clip_name, clip_bytes, "video/mp4")

    try:
        res = requests.post(
            f"{config.BACKEND_URL}/api/v1/engine/alerts",
            data=data, files=files, headers=_HEADERS, timeout=10,
        )
        if res.status_code >= 400:
            log.warning("backend rejected alert %s: %s %s", type_, res.status_code, res.text[:200])
            return False
        return True
    except requests.RequestException as e:
        log.warning("could not reach backend to publish alert %s: %s", type_, e)
        return False


def publish_detections(camera_code: str, detections: list[dict]) -> bool:
    """Best-effort raw detection log push — feeds future accuracy /
    false-positive analytics (DetectionLog on the backend). A dropped batch
    should never interrupt the detection loop, so failures are logged and
    swallowed rather than raised."""
    if not detections:
        return True
    try:
        res = requests.post(
            f"{config.BACKEND_URL}/api/v1/engine/detections",
            json={"camera_code": camera_code, "detections": detections},
            headers=_HEADERS, timeout=5,
        )
        if res.status_code >= 400:
            log.warning("backend rejected detection log batch: %s %s", res.status_code, res.text[:200])
            return False
        return True
    except requests.RequestException as e:
        log.warning("could not reach backend to push detection log: %s", e)
        return False
