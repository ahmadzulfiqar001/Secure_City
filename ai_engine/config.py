"""Central configuration for the SecureCity AI detection worker."""
import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")  # loaded here so it's picked up regardless of entry point
SNAPSHOT_DIR = BASE_DIR / "snapshots"
CLIP_DIR = BASE_DIR / "clips"
VIDEO_DIR = BASE_DIR / "videos"
WEIGHTS_DIR = BASE_DIR / "weights"
MODEL_PATH = BASE_DIR / "yolov8n.pt"
POSE_MODEL_PATH = BASE_DIR / "yolov8n-pose.pt"

# Custom-trained models (see training/README.md) — optional. If the file
# isn't there, the pipeline logs a warning at startup and falls back to the
# existing COCO-proxy / HSV heuristic detectors instead of crashing.
WEAPON_MODEL_PATH = WEIGHTS_DIR / "weapon_best.pt"
FIRE_SMOKE_MODEL_PATH = WEIGHTS_DIR / "fire_smoke_best.pt"

SNAPSHOT_DIR.mkdir(exist_ok=True)
CLIP_DIR.mkdir(exist_ok=True)
VIDEO_DIR.mkdir(exist_ok=True)
WEIGHTS_DIR.mkdir(exist_ok=True)

# ── backend connection ───────────────────────────────────────────────
# The AI engine is a separate worker process — it never touches the
# database directly, it POSTs confirmed alerts (with evidence) to the
# backend's engine-key-gated ingest API (see publisher.py).
BACKEND_URL = os.environ.get("SECURECITY_BACKEND_URL", "http://localhost:8000")
# Shared secret so the ingest endpoint isn't wide open to any caller.
# Must match SECURECITY_ENGINE_KEY in the backend's own .env.
ENGINE_API_KEY = os.environ.get("SECURECITY_ENGINE_KEY", "dev-only-engine-key-change-me")

# Video source: "0" = default webcam index, a file path, or an rtsp:// URL.
DEFAULT_SOURCE = os.environ.get("SECURECITY_SOURCE", "none")
# Must match an existing camera's `code` in the backend (e.g. seeded "CAM-01")
# — camera name/lat/lng/zone/status are fetched live from there, not stored
# locally, so a single source of truth stays in the backend's DB.
DEFAULT_CAMERA_CODE = os.environ.get("SECURECITY_CAMERA_CODE", "CAM-01")

# ── Confidence tuning table ─────────────────────────────────────────
# One place to tune every minimum-confidence cutoff in the system. Lower a
# value to catch more (but noisier) detections; raise it to cut false
# positives. `*_custom` entries only take effect once the matching weights
# file in WEIGHTS_DIR actually exists — see build_detectors() in
# detectors/__init__.py and Pipeline.run().
CONFIDENCE_THRESHOLDS: dict[str, float] = {
    "person": 0.35,          # YOLOv8n (COCO) — base detection model
    "weapon_proxy": 0.40,    # COCO bat/knife/scissors stand-in (fallback, experimental)
    "weapon_custom": 0.45,   # custom-trained Roboflow weapon model, once present
    "object": 0.40,          # backpack/handbag/suitcase (abandoned-object detector)
    "vehicle": 0.40,         # bicycle/car/motorcycle (accident detector)
    "fire_custom": 0.45,     # custom-trained Roboflow fire/smoke model, "fire" class
    "smoke_custom": 0.40,    # custom-trained Roboflow fire/smoke model, "smoke" class
    "fall_pose": 0.5,        # YOLOv8-pose keypoint confidence
}

# ── Detection thresholds ────────────────────────────────────────────
PROCESS_WIDTH = 640          # frames are resized to this width before inference
CONF_PERSON = CONFIDENCE_THRESHOLDS["person"]
CONF_WEAPON = CONFIDENCE_THRESHOLDS["weapon_proxy"]
CONF_OBJECT = CONFIDENCE_THRESHOLDS["object"]

PERSON_CLASS = 0
# EXPERIMENTAL fallback — used only while WEAPON_MODEL_PATH doesn't exist.
# Standing in with COCO classes that are plausible weapon proxies, so the
# alert pipeline can be demoed end to end without a custom model. See
# training/train_weapon.py to replace this with a real trained detector.
WEAPON_CLASSES = {34: "baseball bat", 43: "knife", 76: "scissors"}
OBJECT_CLASSES = {24: "backpack", 26: "handbag", 28: "suitcase"}
# Used by the experimental accident heuristic (motion spike + proximity,
# same technique as the fight detector) — not a real accident-classifier.
VEHICLE_CLASSES = {1: "bicycle", 2: "car", 3: "motorcycle"}

CROWD_THRESHOLD = 8
RUN_SPEED = 1.8
PANIC_RUNNERS = 3
FIGHT_MOTION = 26.0
FIGHT_FRAMES = 5
ACCIDENT_MOTION = 30.0       # slightly higher than fight — a collision is a sharper spike
ACCIDENT_FRAMES = 4

# EXPERIMENTAL fallback — used only while FIRE_SMOKE_MODEL_PATH doesn't
# exist. HSV color heuristic, false-positive prone (orange objects, fog).
# See training/train_fire_smoke.py to replace this with a real trained
# detector.
FIRE_HSV_LOWER = (5, 80, 150)
FIRE_HSV_UPPER = (30, 255, 255)
FIRE_AREA_RATIO = 0.02
FIRE_FRAMES = 6
SMOKE_HSV_LOWER = (0, 0, 90)
SMOKE_HSV_UPPER = (180, 45, 200)
SMOKE_AREA_RATIO = 0.06
SMOKE_FRAMES = 10

# Fall detection (YOLOv8-pose): torso angle from vertical + a sudden drop
# in hip height over a short window. Real keypoints from a real pose
# model — Core tier, not experimental.
FALL_TORSO_ANGLE = 55.0      # degrees from vertical => lying down
FALL_DROP_RATIO = 0.35       # fraction of person height dropped within FALL_WINDOW
FALL_WINDOW = 1.0            # seconds
FALL_CONF = CONFIDENCE_THRESHOLDS["fall_pose"]

# Restricted zone (intrusion detector): a per-camera polygon fetched from
# the backend's camera config (Camera.zone) — see publisher.fetch_camera_config
# and pipeline.py. This many consecutive detected frames with someone
# inside before it fires.
ZONE_FRAMES = 3

ABANDON_SECONDS = 15.0
ABANDON_MOVE_RADIUS = 25.0
ABANDON_PERSON_RADIUS = 140.0

LOITER_SECONDS = 20.0
LOITER_MOVE_RADIUS = 60.0

FACE_BLUR_ENABLED = True

ALERT_COOLDOWN = 20.0        # seconds between repeated alerts of the same type, per camera

CLIP_SECONDS = 10            # evidence clip length once a high-severity alert fires
CLIP_FPS = 10

# Raw per-frame detections are batched and POSTed to the backend's
# detection-log endpoint at most this often (seconds) — feeds future
# accuracy/false-positive analytics without flooding the backend at full
# frame rate.
DETECTION_LOG_INTERVAL = 1.0
