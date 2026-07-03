"""Video capture + YOLOv8 inference loop running on a background thread.

Reads frames from a webcam or video file, runs detection, draws overlays,
keeps the latest annotated JPEG for the MJPEG stream, and writes alerts
(with snapshots) to the database.
"""
import threading
import time
from pathlib import Path

import cv2
import numpy as np

from .. import config, database
from .detectors import FrameData, build_detectors
from .tracker import CentroidTracker

# BGR equivalents of the Flutter app palette (Royal Navy Blue / Gold / White)
COLOR_PRIMARY = (76, 168, 201)   # gold        #C9A84C
COLOR_DANGER = (68, 68, 239)     # red         #EF4444
COLOR_ORANGE = (11, 158, 245)    # orange      #F59E0B
COLOR_ACCENT = (196, 127, 74)    # royal blue  #4A7FC4

SEVERITY_COLOR = {"high": COLOR_DANGER, "medium": COLOR_ORANGE, "low": COLOR_ACCENT}


class DetectionEngine(threading.Thread):
    def __init__(self):
        super().__init__(daemon=True, name="detection-engine")
        self._frame_lock = threading.Lock()
        self._latest_jpeg: bytes = self._placeholder_jpeg("STARTING UP...")
        self._source = config.DEFAULT_SOURCE
        self._source_changed = threading.Event()
        self._stop = threading.Event()

        self.camera_id = config.DEFAULT_CAMERA_ID
        self.model = None
        self.model_ready = False
        self.fps = 0.0
        self.person_count = 0
        self.source_ok = False

        self._tracker = CentroidTracker()
        self._detectors = build_detectors()
        self._prev_gray: np.ndarray | None = None
        self._last_alert_at: dict[str, float] = {}
        self._banner: tuple[str, float] | None = None  # (text, expires_at)

    # ── public API (called from FastAPI handlers) ───────────────────
    def latest_jpeg(self) -> bytes:
        with self._frame_lock:
            return self._latest_jpeg

    def set_source(self, source: str) -> None:
        self._source = source
        self._source_changed.set()

    def set_camera(self, camera_id: str) -> None:
        self.camera_id = config.get_camera(camera_id)["id"]

    def status(self) -> dict:
        src = self._source
        return {
            "model_ready": self.model_ready,
            "source": "webcam" if src.isdigit() else Path(src).name,
            "source_ok": self.source_ok,
            "camera": config.get_camera(self.camera_id),
            "fps": round(self.fps, 1),
            "person_count": self.person_count,
        }

    def stop(self) -> None:
        self._stop.set()

    # ── main loop ───────────────────────────────────────────────────
    def run(self) -> None:
        from ultralytics import YOLO  # heavy import, keep off the main thread

        self._set_placeholder("LOADING YOLOv8 MODEL...")
        self.model = YOLO(str(config.MODEL_PATH))
        self.model_ready = True

        while not self._stop.is_set():
            cap = self._open_capture()
            if cap is None:
                self.source_ok = False
                self._set_placeholder("NO VIDEO SOURCE\nConnect a webcam or upload a video from the admin panel")
                if self._source_changed.wait(timeout=2.0):
                    self._source_changed.clear()
                continue

            self.source_ok = True
            is_file = not self._source.isdigit()
            self._reset_state()

            while not self._stop.is_set() and not self._source_changed.is_set():
                t0 = time.time()
                ok, frame = cap.read()
                if not ok:
                    if is_file:  # loop video files for continuous demo
                        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                        continue
                    break
                self._process_frame(frame)
                self.fps = 0.9 * self.fps + 0.1 * (1.0 / max(time.time() - t0, 1e-3))

            cap.release()
            self._source_changed.clear()

    def _open_capture(self):
        src = self._source
        cap = cv2.VideoCapture(int(src) if src.isdigit() else src)
        if not cap.isOpened():
            return None
        return cap

    def _reset_state(self) -> None:
        self._tracker = CentroidTracker()
        self._detectors = build_detectors()
        self._prev_gray = None

    # ── per-frame pipeline ──────────────────────────────────────────
    def _process_frame(self, frame: np.ndarray) -> None:
        scale = config.PROCESS_WIDTH / frame.shape[1]
        frame = cv2.resize(frame, (config.PROCESS_WIDTH, int(frame.shape[0] * scale)))
        gray = cv2.GaussianBlur(cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), (5, 5), 0)

        results = self.model(
            frame,
            conf=min(config.CONF_PERSON, config.CONF_WEAPON),
            classes=[config.PERSON_CLASS, *config.WEAPON_CLASSES.keys()],
            verbose=False,
        )[0]

        person_boxes, weapons = [], []
        for box in results.boxes:
            cls = int(box.cls[0])
            conf = float(box.conf[0])
            x1, y1, x2, y2 = (float(v) for v in box.xyxy[0])
            if cls == config.PERSON_CLASS and conf >= config.CONF_PERSON:
                person_boxes.append((x1, y1, x2, y2))
            elif cls in config.WEAPON_CLASSES and conf >= config.CONF_WEAPON:
                weapons.append((x1, y1, x2, y2, conf, config.WEAPON_CLASSES[cls]))

        persons = self._tracker.update(person_boxes)
        self.person_count = len(persons)

        data = FrameData(frame, gray, self._prev_gray, persons, weapons)
        for detector in self._detectors:
            for event in detector.update(data):
                self._fire_alert(event, frame)
        self._prev_gray = gray

        self._draw_overlays(frame, persons, weapons)
        ok, jpeg = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        if ok:
            with self._frame_lock:
                self._latest_jpeg = jpeg.tobytes()

    def _fire_alert(self, event, frame: np.ndarray) -> None:
        now = time.time()
        if now - self._last_alert_at.get(event.type, 0.0) < config.ALERT_COOLDOWN:
            return
        self._last_alert_at[event.type] = now

        camera = config.get_camera(self.camera_id)
        name = f"{event.type.lower().replace(' ', '_')}_{int(now)}.jpg"
        cv2.imwrite(str(config.SNAPSHOT_DIR / name), frame)
        database.insert_alert(event.type, event.severity, camera, name, event.details)
        self._banner = (f"{event.type.upper()} — {camera['name']}", now + 3.0)

    # ── drawing ─────────────────────────────────────────────────────
    def _draw_overlays(self, frame, persons, weapons) -> None:
        for tid, track in persons.items():
            x1, y1, x2, y2 = (int(v) for v in track.box)
            running = track.speed() >= config.RUN_SPEED and len(track.history) >= 5
            color = COLOR_ORANGE if running else COLOR_PRIMARY
            label = f"P{tid}" + (" RUNNING" if running else "")
            cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
            cv2.putText(frame, label, (x1, max(y1 - 6, 12)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.45, color, 1, cv2.LINE_AA)

        for x1, y1, x2, y2, conf, label in weapons:
            x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)
            cv2.rectangle(frame, (x1, y1), (x2, y2), COLOR_DANGER, 2)
            cv2.putText(frame, f"WEAPON: {label} {conf:.2f}", (x1, max(y1 - 6, 12)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLOR_DANGER, 2, cv2.LINE_AA)

        self._draw_hud(frame)

        if self._banner and time.time() < self._banner[1]:
            text = self._banner[0]
            overlay = frame.copy()
            cv2.rectangle(overlay, (0, 0), (frame.shape[1], 34), COLOR_DANGER, -1)
            cv2.addWeighted(overlay, 0.65, frame, 0.35, 0, frame)
            cv2.putText(frame, text, (10, 23), cv2.FONT_HERSHEY_SIMPLEX,
                        0.6, (255, 255, 255), 2, cv2.LINE_AA)

    def _draw_hud(self, frame) -> None:
        camera = config.get_camera(self.camera_id)
        h = frame.shape[0]
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, h - 28), (frame.shape[1], h), (20, 15, 13), -1)
        cv2.addWeighted(overlay, 0.6, frame, 0.4, 0, frame)
        hud = (f"{camera['id']} {camera['name']}  |  "
               f"PERSONS: {self.person_count}  |  FPS: {self.fps:.1f}")
        cv2.putText(frame, hud, (10, h - 9), cv2.FONT_HERSHEY_SIMPLEX,
                    0.45, (212, 180, 180), 1, cv2.LINE_AA)
        cv2.circle(frame, (frame.shape[1] - 18, h - 14), 5, COLOR_DANGER, -1)

    # ── placeholder frames when idle ────────────────────────────────
    def _set_placeholder(self, text: str) -> None:
        with self._frame_lock:
            self._latest_jpeg = self._placeholder_jpeg(text)

    @staticmethod
    def _placeholder_jpeg(text: str) -> bytes:
        img = np.full((360, 640, 3), (43, 13, 13), dtype=np.uint8)  # #0D0D2B
        for i, line in enumerate(text.split("\n")):
            size = cv2.getTextSize(line, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 1)[0]
            cv2.putText(img, line, ((640 - size[0]) // 2, 170 + i * 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (212, 180, 180), 1, cv2.LINE_AA)
        ok, jpeg = cv2.imencode(".jpg", img)
        return jpeg.tobytes() if ok else b""


engine = DetectionEngine()
