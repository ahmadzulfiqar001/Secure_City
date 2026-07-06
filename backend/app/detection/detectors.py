"""Alert detectors. Each consumes one FrameData and yields AlertEvents.

Weapon and abandoned-object detection use YOLO classes directly. Fight,
running/panic, overcrowding, fire/smoke, fall, restricted-zone, and
loitering are heuristic (color/motion/tracking based) — acceptable for the
prototype scope and swappable with trained models later (see the comments
on each for exactly what it can't do).
"""
import math
import time
from dataclasses import dataclass, field

import cv2
import numpy as np

from .. import config
from .tracker import Track


@dataclass
class AlertEvent:
    type: str
    severity: str  # high | medium | low
    details: dict = field(default_factory=dict)


@dataclass
class FrameData:
    frame: np.ndarray                 # BGR, resized
    gray: np.ndarray                  # grayscale of current frame
    prev_gray: np.ndarray | None      # grayscale of previous frame
    persons: dict[int, Track]         # active person tracks
    weapons: list[tuple]              # (x1, y1, x2, y2, conf, label)
    objects: list[tuple] = field(default_factory=list)   # (x1, y1, x2, y2, conf, label) — bags/suitcases


class WeaponDetector:
    def update(self, data: FrameData) -> list[AlertEvent]:
        if not data.weapons:
            return []
        labels = sorted({w[5] for w in data.weapons})
        return [AlertEvent(
            "Weapon Detected", "high",
            {"objects": labels, "count": len(data.weapons)},
        )]


class CrowdDetector:
    def update(self, data: FrameData) -> list[AlertEvent]:
        count = len(data.persons)
        if count >= config.CROWD_THRESHOLD:
            return [AlertEvent(
                "Overcrowding", "medium", {"person_count": count},
            )]
        return []


class RunningDetector:
    def update(self, data: FrameData) -> list[AlertEvent]:
        runners = [
            tid for tid, t in data.persons.items()
            if t.speed() >= config.RUN_SPEED and len(t.history) >= 5
        ]
        if not runners:
            return []
        if len(runners) >= config.PANIC_RUNNERS:
            return [AlertEvent(
                "Panic Movement", "high",
                {"runners": len(runners), "person_count": len(data.persons)},
            )]
        return [AlertEvent(
            "Person Running", "low", {"runners": len(runners)},
        )]


class FightDetector:
    """Close pair of persons + sustained high motion in their region."""

    def __init__(self):
        self.streak = 0

    def update(self, data: FrameData) -> list[AlertEvent]:
        hit = False
        if data.prev_gray is not None and len(data.persons) >= 2:
            motion = cv2.absdiff(data.gray, data.prev_gray)
            tracks = list(data.persons.values())
            for i in range(len(tracks)):
                for j in range(i + 1, len(tracks)):
                    if self._pair_fighting(tracks[i], tracks[j], motion):
                        hit = True
                        break
                if hit:
                    break

        self.streak = self.streak + 1 if hit else max(self.streak - 1, 0)
        if self.streak >= config.FIGHT_FRAMES:
            self.streak = -config.FIGHT_FRAMES  # hysteresis before re-firing
            return [AlertEvent(
                "Fight Detected", "high", {"person_count": len(data.persons)},
            )]
        return []

    @staticmethod
    def _pair_fighting(a: Track, b: Track, motion: np.ndarray) -> bool:
        ax1, ay1, ax2, ay2 = a.box
        bx1, by1, bx2, by2 = b.box
        acx, acy = a.centroid
        bcx, bcy = b.centroid
        avg_w = ((ax2 - ax1) + (bx2 - bx1)) / 2
        dist = ((acx - bcx) ** 2 + (acy - bcy) ** 2) ** 0.5
        if dist > 1.2 * avg_w:
            return False
        x1 = max(int(min(ax1, bx1)), 0)
        y1 = max(int(min(ay1, by1)), 0)
        x2 = min(int(max(ax2, bx2)), motion.shape[1])
        y2 = min(int(max(ay2, by2)), motion.shape[0])
        if x2 <= x1 or y2 <= y1:
            return False
        region = motion[y1:y2, x1:x2]
        return float(region.mean()) >= config.FIGHT_MOTION


class FireSmokeDetector:
    """HSV color-threshold heuristic — no fire/smoke class exists in
    COCO/YOLOv8n. Flags a sustained run of frames where a large-enough
    fraction of the image matches a fire-like or smoke-like color range.
    False-positive prone (orange objects, fog, pale walls); a real
    deployment would replace this with a model trained on fire imagery."""

    def __init__(self):
        self.fire_streak = 0
        self.smoke_streak = 0

    def update(self, data: FrameData) -> list[AlertEvent]:
        hsv = cv2.cvtColor(data.frame, cv2.COLOR_BGR2HSV)
        events = []

        # `>=` + reset-to-negative (not reset-to-0) so a *sustained* fire/smoke
        # condition keeps re-arming and periodically re-fires (rate-limited by
        # the engine's ALERT_COOLDOWN) instead of alerting once and going
        # silent for the rest of the event — same hysteresis FightDetector uses.
        fire_mask = cv2.inRange(hsv, config.FIRE_HSV_LOWER, config.FIRE_HSV_UPPER)
        fire_ratio = cv2.countNonZero(fire_mask) / fire_mask.size
        self.fire_streak = self.fire_streak + 1 if fire_ratio >= config.FIRE_AREA_RATIO else max(self.fire_streak - 1, 0)
        if self.fire_streak >= config.FIRE_FRAMES:
            self.fire_streak = -config.FIRE_FRAMES
            events.append(AlertEvent("Fire Detected", "high", {"coverage": round(float(fire_ratio), 3)}))

        smoke_mask = cv2.inRange(hsv, config.SMOKE_HSV_LOWER, config.SMOKE_HSV_UPPER)
        smoke_ratio = cv2.countNonZero(smoke_mask) / smoke_mask.size
        self.smoke_streak = self.smoke_streak + 1 if smoke_ratio >= config.SMOKE_AREA_RATIO else max(self.smoke_streak - 1, 0)
        if self.smoke_streak >= config.SMOKE_FRAMES:
            self.smoke_streak = -config.SMOKE_FRAMES
            events.append(AlertEvent("Smoke Detected", "high", {"coverage": round(float(smoke_ratio), 3)}))

        return events


class FallDetector:
    """A standing person's box is taller than wide; flip that ratio for a
    few consecutive frames and call it a fall. Shape-based, not a real pose
    estimator, so a person bending over or sitting oddly can false-positive."""

    def __init__(self):
        self.streaks: dict[int, int] = {}

    def update(self, data: FrameData) -> list[AlertEvent]:
        for tid in list(self.streaks.keys()):
            if tid not in data.persons:
                del self.streaks[tid]

        events = []
        for tid, track in data.persons.items():
            x1, y1, x2, y2 = track.box
            ratio = (x2 - x1) / max(y2 - y1, 1.0)
            streak = self.streaks.get(tid, 0)
            streak = streak + 1 if ratio >= config.FALL_ASPECT_RATIO else 0
            self.streaks[tid] = streak
            if streak == config.FALL_FRAMES:
                events.append(AlertEvent("Fall Detected", "high", {"track_id": tid}))
        return events


class RestrictedZoneDetector:
    """Alerts when a tracked person's foot-point enters `config.RESTRICTED_ZONE`
    (a configurable polygon in fractional frame coordinates)."""

    def __init__(self):
        self.streak = 0

    def update(self, data: FrameData) -> list[AlertEvent]:
        h, w = data.frame.shape[:2]
        polygon = np.array([(px * w, py * h) for px, py in config.RESTRICTED_ZONE], dtype=np.float32)

        intruders = 0
        for track in data.persons.values():
            x1, y1, x2, y2 = track.box
            foot = ((x1 + x2) / 2, y2)
            if cv2.pointPolygonTest(polygon, foot, False) >= 0:
                intruders += 1

        # Same re-arming hysteresis as FireSmokeDetector — someone lingering
        # in the zone should keep re-alerting (cooldown-limited by the
        # engine), not fire once and go quiet for the rest of their visit.
        self.streak = self.streak + 1 if intruders > 0 else max(self.streak - 1, 0)
        if self.streak >= config.ZONE_FRAMES:
            self.streak = -config.ZONE_FRAMES
            return [AlertEvent("Restricted Area Intrusion", "medium", {"intruders": intruders})]
        return []


class AbandonedObjectDetector:
    """Tracks bag-like objects (COCO backpack/handbag/suitcase) with their
    own lightweight tracker (dwell time needs longer memory than the
    per-frame person tracker keeps). Fires once an object has sat within a
    small radius, with no person nearby, for `config.ABANDON_SECONDS`."""

    def __init__(self):
        self._objects: dict[int, dict] = {}
        self._next_id = 1
        self._fired: set[int] = set()

    def update(self, data: FrameData) -> list[AlertEvent]:
        now = time.time()
        matched: set[int] = set()

        for x1, y1, x2, y2, _conf, label in data.objects:
            cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
            best_id, best_dist = None, 60.0
            for oid, o in self._objects.items():
                if oid in matched:
                    continue
                d = math.hypot(cx - o["cx"], cy - o["cy"])
                if d < best_dist:
                    best_id, best_dist = oid, d

            if best_id is None:
                best_id = self._next_id
                self._next_id += 1
                self._objects[best_id] = {
                    "cx": cx, "cy": cy, "origin": (cx, cy), "label": label,
                    "first_seen": now, "last_seen": now,
                }
            else:
                o = self._objects[best_id]
                if math.hypot(cx - o["origin"][0], cy - o["origin"][1]) > config.ABANDON_MOVE_RADIUS:
                    o["origin"] = (cx, cy)
                    o["first_seen"] = now
                    self._fired.discard(best_id)
                o["cx"], o["cy"], o["last_seen"] = cx, cy, now
            matched.add(best_id)

        for oid in list(self._objects.keys()):
            if now - self._objects[oid]["last_seen"] > 5.0:
                del self._objects[oid]
                self._fired.discard(oid)

        events = []
        for oid, o in self._objects.items():
            if oid in self._fired or now - o["first_seen"] < config.ABANDON_SECONDS:
                continue
            attended = any(
                math.hypot(o["cx"] - t.centroid[0], o["cy"] - t.centroid[1]) < config.ABANDON_PERSON_RADIUS
                for t in data.persons.values()
            )
            if not attended:
                self._fired.add(oid)
                events.append(AlertEvent(
                    "Abandoned Object", "medium",
                    {"object": o["label"], "dwell_seconds": round(now - o["first_seen"], 1)},
                ))
        return events


class LoiteringDetector:
    """A tracked person who drifts less than `config.LOITER_MOVE_RADIUS` px
    for `config.LOITER_SECONDS` gets flagged once (resets if they move away
    or leave the frame)."""

    def __init__(self):
        self._tracks: dict[int, dict] = {}
        self._fired: set[int] = set()

    def update(self, data: FrameData) -> list[AlertEvent]:
        now = time.time()
        for tid in list(self._tracks.keys()):
            if tid not in data.persons:
                del self._tracks[tid]
                self._fired.discard(tid)

        events = []
        for tid, track in data.persons.items():
            cx, cy = track.centroid
            if tid not in self._tracks:
                self._tracks[tid] = {"origin": (cx, cy), "first_seen": now}
                continue

            o = self._tracks[tid]
            if math.hypot(cx - o["origin"][0], cy - o["origin"][1]) > config.LOITER_MOVE_RADIUS:
                o["origin"] = (cx, cy)
                o["first_seen"] = now
                self._fired.discard(tid)
                continue

            if tid not in self._fired and now - o["first_seen"] >= config.LOITER_SECONDS:
                self._fired.add(tid)
                events.append(AlertEvent(
                    "Suspicious Loitering", "low",
                    {"track_id": tid, "seconds": round(now - o["first_seen"], 1)},
                ))
        return events


def build_detectors() -> list:
    return [
        WeaponDetector(),
        FightDetector(),
        RunningDetector(),
        CrowdDetector(),
        FireSmokeDetector(),
        FallDetector(),
        RestrictedZoneDetector(),
        AbandonedObjectDetector(),
        LoiteringDetector(),
    ]
