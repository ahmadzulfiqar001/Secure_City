"""Main detection loop. Run via the CLI:

    python -m ai_engine --camera CAM-01 --source demo.mp4

Frame loop: ingestion -> YOLOv8 (+ByteTrack) detection -> YOLOv8-pose ->
optional custom weapon/fire-smoke models -> detectors -> evidence capture
-> publisher (HTTP POST to the backend). This process never imports the
backend's database — see publisher.py.
"""
import logging
import time

import cv2
import numpy as np

from . import config
from .detectors import FrameData, build_detectors
from .detectors.tracker import TrackStore
from .evidence import ClipBuffer, FaceBlurrer, save_snapshot
from .ingestion.source import VideoSource
from .publisher import fetch_camera_config, publish_alert, publish_detections

log = logging.getLogger("ai_engine.pipeline")


class Pipeline:
    def __init__(self, source: str | None = None, camera_code: str | None = None):
        self.source = source or config.DEFAULT_SOURCE
        self.camera_code = camera_code or config.DEFAULT_CAMERA_CODE
        self.camera: dict | None = None  # fetched from the backend at startup
        self.model = None
        self.pose_model = None
        self.weapon_model = None       # custom-trained, only if WEAPON_MODEL_PATH exists
        self.fire_smoke_model = None   # custom-trained, only if FIRE_SMOKE_MODEL_PATH exists
        self.model_ready = False
        self.fps = 0.0
        self.person_count = 0
        self.source_ok = False
        self._stopped = False
        self._last_detection_log_push = 0.0

        self._tracker = TrackStore()
        self._detectors: list = []
        self._face_blur = FaceBlurrer()
        self._clip_buffer = ClipBuffer()
        self._prev_gray: np.ndarray | None = None
        self._last_alert_at: dict[str, float] = {}

    def stop(self) -> None:
        self._stopped = True

    def run(self) -> None:
        log.info("fetching camera config for '%s' from backend...", self.camera_code)
        self.camera = fetch_camera_config(self.camera_code)
        if self.camera is None:
            log.error(
                "could not fetch config for camera '%s' — is the backend running and is this "
                "camera code seeded there? aborting.", self.camera_code,
            )
            return
        log.info("camera config: %s", self.camera)

        log.info("loading YOLOv8 detection model...")
        from ultralytics import YOLO
        self.model = YOLO(str(config.MODEL_PATH))
        log.info("loading YOLOv8-pose model...")
        self.pose_model = YOLO(str(config.POSE_MODEL_PATH))

        self.weapon_model = self._load_optional_model(
            config.WEAPON_MODEL_PATH,
            "custom weapon-detection model",
            "training/train_weapon.py",
        )
        self.fire_smoke_model = self._load_optional_model(
            config.FIRE_SMOKE_MODEL_PATH,
            "custom fire/smoke-detection model",
            "training/train_fire_smoke.py",
        )
        self._detectors = build_detectors(
            zone_polygon=self.camera.get("zone"),
            weapon_model_loaded=self.weapon_model is not None,
            fire_smoke_model_loaded=self.fire_smoke_model is not None,
        )

        self.model_ready = True
        log.info("models ready")

        video = VideoSource(self.source)
        if not video.open():
            self.source_ok = False
            log.error("could not open video source: %s", self.source)
            return
        self.source_ok = True
        log.info("video source open: %s (camera=%s)", self.source, self.camera_code)

        while not self._stopped:
            t0 = time.time()
            ok, frame = video.read()
            if not ok:
                log.info("video source ended")
                break
            self._process_frame(frame)
            self.fps = 0.9 * self.fps + 0.1 * (1.0 / max(time.time() - t0, 1e-3))

        video.release()
        self.source_ok = False

    @staticmethod
    def _load_optional_model(path, label: str, training_script: str):
        """Graceful fallback: a missing custom-model weights file is not a
        crash — it's a clearly logged warning, and the pipeline keeps
        running on the existing experimental heuristic detector instead."""
        if not path.exists():
            log.warning(
                "%s not found at %s — falling back to the experimental heuristic detector. "
                "Run ai_engine/%s to train and export real weights there.",
                label, path, training_script,
            )
            return None
        log.info("loading %s from %s...", label, path)
        from ultralytics import YOLO
        return YOLO(str(path))

    def _process_frame(self, frame: np.ndarray) -> None:
        scale = config.PROCESS_WIDTH / frame.shape[1]
        frame = cv2.resize(frame, (config.PROCESS_WIDTH, int(frame.shape[0] * scale)))
        raw_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(raw_gray, (5, 5), 0)

        results = self.model.track(
            frame,
            persist=True,
            tracker="bytetrack.yaml",
            conf=min(config.CONF_PERSON, config.CONF_WEAPON, config.CONF_OBJECT),
            classes=[config.PERSON_CLASS, *config.WEAPON_CLASSES.keys(), *config.OBJECT_CLASSES.keys(), *config.VEHICLE_CLASSES.keys()],
            verbose=False,
        )[0]

        person_boxes_by_id: dict[int, tuple] = {}
        weapons, objects, vehicles = [], [], []
        raw_detections = []
        if results.boxes is not None and len(results.boxes) > 0:
            ids = results.boxes.id
            for i in range(len(results.boxes)):
                box = results.boxes[i]
                cls = int(box.cls[0])
                conf = float(box.conf[0])
                x1, y1, x2, y2 = (float(v) for v in box.xyxy[0])
                tid = int(ids[i]) if ids is not None else None
                if cls == config.PERSON_CLASS and conf >= config.CONF_PERSON:
                    person_boxes_by_id[tid if tid is not None else -(i + 1)] = (x1, y1, x2, y2)
                    raw_detections.append(("yolov8n", "person", conf, tid, (x1, y1, x2, y2)))
                elif cls in config.WEAPON_CLASSES and conf >= config.CONF_WEAPON:
                    weapons.append((x1, y1, x2, y2, conf, config.WEAPON_CLASSES[cls]))
                    raw_detections.append(("yolov8n", config.WEAPON_CLASSES[cls], conf, tid, (x1, y1, x2, y2)))
                elif cls in config.OBJECT_CLASSES and conf >= config.CONF_OBJECT:
                    objects.append((x1, y1, x2, y2, conf, config.OBJECT_CLASSES[cls]))
                    raw_detections.append(("yolov8n", config.OBJECT_CLASSES[cls], conf, tid, (x1, y1, x2, y2)))
                elif cls in config.VEHICLE_CLASSES and conf >= config.CONFIDENCE_THRESHOLDS["vehicle"]:
                    vehicles.append((x1, y1, x2, y2, conf, config.VEHICLE_CLASSES[cls]))
                    raw_detections.append(("yolov8n", config.VEHICLE_CLASSES[cls], conf, tid, (x1, y1, x2, y2)))

        persons = self._tracker.update(person_boxes_by_id)
        self.person_count = len(persons)

        # Separate pose pass (fall detection needs real keypoints, which the
        # main detection model doesn't produce).
        pose_persons = []
        pose_results = self.pose_model(frame, conf=config.FALL_CONF, verbose=False)[0]
        if pose_results.keypoints is not None and pose_results.boxes is not None and len(pose_results.boxes) > 0:
            kpts_all = pose_results.keypoints.data.cpu().numpy()  # (N, 17, 3)
            for i in range(len(pose_results.boxes)):
                box = pose_results.boxes[i]
                conf = float(box.conf[0])
                x1, y1, x2, y2 = (float(v) for v in box.xyxy[0])
                pose_persons.append(((x1, y1, x2, y2), kpts_all[i], conf))

        custom_weapon_boxes = self._run_custom_model(
            self.weapon_model, frame, config.CONFIDENCE_THRESHOLDS["weapon_custom"], raw_detections, "weapon_custom",
        )
        custom_fire_smoke_boxes = self._run_custom_model(
            self.fire_smoke_model, frame,
            min(config.CONFIDENCE_THRESHOLDS["fire_custom"], config.CONFIDENCE_THRESHOLDS["smoke_custom"]),
            raw_detections, "fire_smoke_custom",
        )

        # Face blur applied before anything is saved or streamed anywhere.
        self._face_blur.apply(frame, raw_gray)
        self._clip_buffer.push(frame)
        self._push_detection_log(raw_detections)

        data = FrameData(
            frame, gray, self._prev_gray, persons, weapons, objects, pose_persons,
            vehicles, custom_weapon_boxes, custom_fire_smoke_boxes,
        )
        for detector in self._detectors:
            for event in detector.update(data):
                self._fire_alert(event, frame)
        self._prev_gray = gray

    @staticmethod
    def _run_custom_model(model, frame: np.ndarray, conf: float, raw_detections: list, model_name: str) -> list[tuple]:
        """Runs a custom-trained model (weapon or fire/smoke) as its own
        inference pass, same pattern as the pose model — its classes don't
        overlap with the base YOLOv8n/COCO pass. Also feeds raw_detections
        for the detection-log push. No-op if the model wasn't loaded."""
        if model is None:
            return []
        boxes_out = []
        results = model(frame, conf=conf, verbose=False)[0]
        if results.boxes is not None and len(results.boxes) > 0:
            names = results.names
            for i in range(len(results.boxes)):
                box = results.boxes[i]
                cls = int(box.cls[0])
                bconf = float(box.conf[0])
                x1, y1, x2, y2 = (float(v) for v in box.xyxy[0])
                label = names.get(cls, str(cls))
                boxes_out.append((x1, y1, x2, y2, bconf, label))
                raw_detections.append((model_name, label, bconf, None, (x1, y1, x2, y2)))
        return boxes_out

    def _push_detection_log(self, raw_detections: list) -> None:
        now = time.time()
        if not raw_detections or now - self._last_detection_log_push < config.DETECTION_LOG_INTERVAL:
            return
        self._last_detection_log_push = now
        rows = [
            {"model_name": str(model_name), "class_name": class_name, "confidence": round(conf, 3),
             "track_id": track_id, "bbox": [round(v, 1) for v in bbox]}
            for model_name, class_name, conf, track_id, bbox in raw_detections
        ]
        publish_detections(self.camera_code, rows)

    def _fire_alert(self, event, frame: np.ndarray) -> None:
        now = time.time()
        if now - self._last_alert_at.get(event.type, 0.0) < config.ALERT_COOLDOWN:
            return
        self._last_alert_at[event.type] = now

        base = event.type.lower().replace(" ", "_")
        snapshot_name = f"{base}_{int(now)}.jpg"
        save_snapshot(frame, snapshot_name)
        ok_jpeg, jpeg_bytes = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 90])

        clip_name, clip_bytes = None, None
        if event.severity in ("critical", "high"):
            clip_name = f"{base}_{int(now)}.mp4"
            saved = self._clip_buffer.save_clip(clip_name)
            if saved:
                with open(config.CLIP_DIR / clip_name, "rb") as f:
                    clip_bytes = f.read()
            else:
                clip_name = None

        ok = publish_alert(
            event.type, event.severity, self.camera_code, event.confidence, event.experimental,
            event.details, snapshot_name, jpeg_bytes.tobytes() if ok_jpeg else b"",
            clip_name, clip_bytes,
        )
        log.info(
            "%s alert '%s' (%s)%s",
            "published" if ok else "FAILED to publish",
            event.type, event.severity,
            " [experimental]" if event.experimental else "",
        )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    Pipeline().run()
