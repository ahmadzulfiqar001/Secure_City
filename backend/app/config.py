"""Central configuration for the SecureCity detection backend."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
SNAPSHOT_DIR = BASE_DIR / "snapshots"
VIDEO_DIR = BASE_DIR / "videos"
ADMIN_DIR = BASE_DIR / "admin"
DB_PATH = BASE_DIR / "securecity.db"
MODEL_PATH = BASE_DIR / "yolov8n.pt"

SNAPSHOT_DIR.mkdir(exist_ok=True)
VIDEO_DIR.mkdir(exist_ok=True)

# Video source: "0" = default webcam, or a path to a video file.
DEFAULT_SOURCE = os.environ.get("SECURECITY_SOURCE", "0")

# ── Detection thresholds ────────────────────────────────────────────
PROCESS_WIDTH = 640          # frames are resized to this width before inference
CONF_PERSON = 0.35
CONF_WEAPON = 0.40
# COCO classes treated as weapons (prototype; a custom-trained gun/knife
# model can replace yolov8n.pt without code changes)
PERSON_CLASS = 0
WEAPON_CLASSES = {34: "baseball bat", 43: "knife", 76: "scissors"}

CROWD_THRESHOLD = 8          # persons in frame => overcrowding
RUN_SPEED = 1.8              # body-heights per second => running
PANIC_RUNNERS = 3            # simultaneous runners => panic movement
FIGHT_MOTION = 26.0          # mean frame-diff intensity inside a close pair region
FIGHT_FRAMES = 5             # consecutive high-motion frames => fight

ALERT_COOLDOWN = 20.0        # seconds between repeated alerts of the same type

# ── Cameras (must stay in sync with the Flutter app's demo pins) ───
CAMERAS = [
    {"id": "CAM-01", "name": "Saddar Market",  "lat": 33.7294, "lng": 73.0931},
    {"id": "CAM-02", "name": "Raja Bazaar",    "lat": 33.7296, "lng": 73.0880},
    {"id": "CAM-03", "name": "Blue Area",      "lat": 33.7215, "lng": 73.0433},
    {"id": "CAM-04", "name": "F-10 Markaz",    "lat": 33.7080, "lng": 73.0479},
    {"id": "CAM-05", "name": "Centaurus Mall", "lat": 33.6938, "lng": 73.0651},
    {"id": "CAM-06", "name": "Liaquat Bagh",   "lat": 33.6844, "lng": 73.0479},
]
DEFAULT_CAMERA_ID = "CAM-01"


def get_camera(camera_id: str) -> dict:
    for cam in CAMERAS:
        if cam["id"] == camera_id:
            return cam
    return CAMERAS[0]
