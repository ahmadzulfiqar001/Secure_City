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
    # Rawalpindi / Islamabad
    {"id": "CAM-01", "name": "Saddar Market, Rawalpindi",         "lat": 33.7294, "lng": 73.0931},
    {"id": "CAM-02", "name": "Raja Bazaar, Rawalpindi",           "lat": 33.7296, "lng": 73.0880},
    {"id": "CAM-03", "name": "Blue Area, Islamabad",              "lat": 33.7215, "lng": 73.0433},
    {"id": "CAM-04", "name": "F-10 Markaz, Islamabad",            "lat": 33.7080, "lng": 73.0479},
    {"id": "CAM-05", "name": "Centaurus Mall, Islamabad",         "lat": 33.6938, "lng": 73.0651},
    {"id": "CAM-06", "name": "Liaquat Bagh, Rawalpindi",          "lat": 33.6844, "lng": 73.0479},
    {"id": "CAM-07", "name": "G-9 Markaz, Islamabad",             "lat": 33.6996, "lng": 73.0362},
    # Lahore
    {"id": "CAM-08", "name": "Mall Road, Lahore",                 "lat": 31.5497, "lng": 74.3436},
    {"id": "CAM-09", "name": "Liberty Market, Lahore",            "lat": 31.5085, "lng": 74.3436},
    # Karachi
    {"id": "CAM-10", "name": "Saddar Town, Karachi",              "lat": 24.8608, "lng": 67.0104},
    {"id": "CAM-11", "name": "Clifton Beach, Karachi",            "lat": 24.8138, "lng": 67.0299},
    # Other major cities
    {"id": "CAM-12", "name": "Qissa Khwani Bazaar, Peshawar",     "lat": 34.0083, "lng": 71.5787},
    {"id": "CAM-13", "name": "Liaquat Bazaar, Quetta",            "lat": 30.1798, "lng": 66.9750},
    {"id": "CAM-14", "name": "Ghanta Ghar, Multan",               "lat": 30.1978, "lng": 71.4697},
    {"id": "CAM-15", "name": "Clock Tower, Faisalabad",           "lat": 31.4187, "lng": 73.0791},
    {"id": "CAM-16", "name": "Cantt Area, Sialkot",               "lat": 32.4927, "lng": 74.5310},
]
DEFAULT_CAMERA_ID = "CAM-01"


def get_camera(camera_id: str) -> dict:
    for cam in CAMERAS:
        if cam["id"] == camera_id:
            return cam
    return CAMERAS[0]
