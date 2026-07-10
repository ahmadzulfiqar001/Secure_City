"""Two implementations, picked by build_detectors() based on whether
FIRE_SMOKE_MODEL_PATH exists:

- FireSmokeDetector: EXPERIMENTAL fallback. HSV color-threshold heuristic —
  no fire/smoke class exists in COCO/YOLOv8n and no Roboflow-trained model
  is wired up. Flags a sustained run of frames where a large-enough
  fraction of the image matches a fire-like or smoke-like color range.
  False-positive prone (orange objects, fog, pale walls). See
  training/train_fire_smoke.py to replace this with a real trained model.
- CustomFireSmokeDetector: wraps a real trained fire/smoke model's output
  (Pipeline runs it as a separate inference pass) — not experimental.
"""
import cv2

from .. import config
from .base import AlertEvent, FrameData


class FireSmokeDetector:
    def __init__(self):
        self.fire_streak = 0
        self.smoke_streak = 0

    def update(self, data: FrameData) -> list[AlertEvent]:
        hsv = cv2.cvtColor(data.frame, cv2.COLOR_BGR2HSV)
        events = []

        # `>=` + reset-to-negative (not reset-to-0) so a *sustained* fire/smoke
        # condition keeps re-arming and periodically re-fires (rate-limited by
        # the pipeline's ALERT_COOLDOWN) instead of alerting once and going
        # silent for the rest of the event.
        fire_mask = cv2.inRange(hsv, config.FIRE_HSV_LOWER, config.FIRE_HSV_UPPER)
        fire_ratio = cv2.countNonZero(fire_mask) / fire_mask.size
        self.fire_streak = self.fire_streak + 1 if fire_ratio >= config.FIRE_AREA_RATIO else max(self.fire_streak - 1, 0)
        if self.fire_streak >= config.FIRE_FRAMES:
            self.fire_streak = -config.FIRE_FRAMES
            events.append(AlertEvent(
                "Fire Detected", "critical", confidence=round(float(fire_ratio), 2), experimental=True,
                details={"coverage": round(float(fire_ratio), 3), "model": "hsv_heuristic"},
            ))

        smoke_mask = cv2.inRange(hsv, config.SMOKE_HSV_LOWER, config.SMOKE_HSV_UPPER)
        smoke_ratio = cv2.countNonZero(smoke_mask) / smoke_mask.size
        self.smoke_streak = self.smoke_streak + 1 if smoke_ratio >= config.SMOKE_AREA_RATIO else max(self.smoke_streak - 1, 0)
        if self.smoke_streak >= config.SMOKE_FRAMES:
            self.smoke_streak = -config.SMOKE_FRAMES
            events.append(AlertEvent(
                "Smoke Detected", "high", confidence=round(float(smoke_ratio), 2), experimental=True,
                details={"coverage": round(float(smoke_ratio), 3), "model": "hsv_heuristic"},
            ))

        return events


class CustomFireSmokeDetector:
    def __init__(self):
        self.fire_streak = 0
        self.smoke_streak = 0

    def update(self, data: FrameData) -> list[AlertEvent]:
        fire_boxes = [b for b in data.custom_fire_smoke_boxes if b[5] == "fire"]
        smoke_boxes = [b for b in data.custom_fire_smoke_boxes if b[5] == "smoke"]
        events = []

        self.fire_streak = self.fire_streak + 1 if fire_boxes else max(self.fire_streak - 1, 0)
        if self.fire_streak >= config.FIRE_FRAMES:
            self.fire_streak = -config.FIRE_FRAMES
            events.append(AlertEvent(
                "Fire Detected", "critical", confidence=round(max(b[4] for b in fire_boxes), 2), experimental=False,
                details={"count": len(fire_boxes), "model": "custom"},
            ))

        self.smoke_streak = self.smoke_streak + 1 if smoke_boxes else max(self.smoke_streak - 1, 0)
        if self.smoke_streak >= config.SMOKE_FRAMES:
            self.smoke_streak = -config.SMOKE_FRAMES
            events.append(AlertEvent(
                "Smoke Detected", "high", confidence=round(max(b[4] for b in smoke_boxes), 2), experimental=False,
                details={"count": len(smoke_boxes), "model": "custom"},
            ))

        return events
