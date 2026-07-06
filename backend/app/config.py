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

# Fire/smoke are classical HSV-color heuristics, not a trained model — no
# "fire"/"smoke" class exists in COCO/YOLOv8n. Prone to false positives on
# orange objects (fire) or fog/pale walls (smoke); good enough to demo the
# alert pipeline, not a substitute for a trained fire-detection model.
FIRE_HSV_LOWER = (5, 80, 150)      # orange/red/yellow, bright + saturated
FIRE_HSV_UPPER = (30, 255, 255)
FIRE_AREA_RATIO = 0.02             # fraction of frame that must match
FIRE_FRAMES = 6                    # consecutive matching frames => alert

SMOKE_HSV_LOWER = (0, 0, 90)       # low-saturation grey/white haze
SMOKE_HSV_UPPER = (180, 45, 200)
SMOKE_AREA_RATIO = 0.06
SMOKE_FRAMES = 10

# Fall detection: a standing person's box is taller than it is wide; a
# fallen one flips that. Heuristic on box shape, not pose estimation.
FALL_ASPECT_RATIO = 1.3      # width / height above this => lying down
FALL_FRAMES = 6

# Restricted zone: fractional (0-1) frame coordinates, top-left origin.
# Demo default is the top-left ~28%x35% of frame — reposition per camera.
RESTRICTED_ZONE = [(0.0, 0.0), (0.28, 0.0), (0.28, 0.35), (0.0, 0.35)]
ZONE_FRAMES = 3               # consecutive frames with someone inside => alert

# Abandoned object: COCO classes that plausibly are "a bag someone left".
OBJECT_CLASSES = {24: "backpack", 26: "handbag", 28: "suitcase"}
CONF_OBJECT = 0.40
ABANDON_SECONDS = 15.0        # stationary+unattended duration => alert
ABANDON_MOVE_RADIUS = 25.0    # px drift still counted as "stationary"
ABANDON_PERSON_RADIUS = 140.0 # px — a person this close counts as "attending" it

# Loitering: a person who barely moves for a long stretch.
LOITER_SECONDS = 20.0
LOITER_MOVE_RADIUS = 60.0

# Face blur: real-time privacy masking via OpenCV's built-in Haar cascade
# (no custom model needed). Applied to the live stream and saved snapshots.
FACE_BLUR_ENABLED = True

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
