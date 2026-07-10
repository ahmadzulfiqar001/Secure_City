"""Custom tier (per spec A3): YOLOv8-pose keypoint heuristic — torso angle
from vertical + a sudden drop in hip height over a short window. Real
keypoints from a real pose model (not a shape/aspect-ratio guess), but
still a heuristic rule on top rather than a trained fall-classifier, so a
person bending down quickly can still false-positive.
"""
import math
import time

from .. import config
from .base import AlertEvent, FrameData

# COCO-17 keypoint indices used here
L_SHOULDER, R_SHOULDER = 5, 6
L_HIP, R_HIP = 11, 12


def _valid(kp) -> bool:
    return kp[2] >= config.FALL_CONF


class FallDetector:
    """Keeps its own short-lived, centroid-matched tracker — pose
    detections aren't unified with the main ByteTrack id space, so this
    matches frame-to-frame on proximity instead."""

    def __init__(self):
        self._people: dict[int, dict] = {}
        self._next_id = 1
        self._fired: set[int] = set()

    def update(self, data: FrameData) -> list[AlertEvent]:
        now = time.time()
        matched: set[int] = set()
        events = []

        for box, kpts, conf in data.pose_persons:
            x1, y1, x2, y2 = box
            cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
            height = max(y2 - y1, 1.0)

            best_id, best_dist = None, 80.0
            for pid, p in self._people.items():
                if pid in matched:
                    continue
                d = math.hypot(cx - p["cx"], cy - p["cy"])
                if d < best_dist:
                    best_id, best_dist = pid, d

            if best_id is None:
                best_id = self._next_id
                self._next_id += 1
                self._people[best_id] = {"history": [], "cx": cx, "cy": cy, "last_seen": now}
            person = self._people[best_id]
            person["cx"], person["cy"], person["last_seen"] = cx, cy, now
            matched.add(best_id)

            angle = self._torso_angle(kpts)
            hip_y = self._hip_y(kpts)
            if hip_y is not None:
                person["history"].append((now, hip_y, height))
                person["history"] = [e for e in person["history"] if now - e[0] <= config.FALL_WINDOW + 0.5]

            if angle is None or hip_y is None:
                continue

            fallen = angle >= config.FALL_TORSO_ANGLE and self._sudden_drop(person["history"], now)

            if fallen and best_id not in self._fired:
                self._fired.add(best_id)
                events.append(AlertEvent(
                    "Fall Detected", "critical", confidence=round(float(conf), 2),
                    details={"torso_angle": round(angle, 1)},
                ))
            elif not fallen:
                self._fired.discard(best_id)

        for pid in list(self._people.keys()):
            if now - self._people[pid]["last_seen"] > 5.0:
                del self._people[pid]
                self._fired.discard(pid)

        return events

    @staticmethod
    def _torso_angle(kpts) -> float | None:
        ls, rs, lh, rh = kpts[L_SHOULDER], kpts[R_SHOULDER], kpts[L_HIP], kpts[R_HIP]
        if not all(_valid(p) for p in (ls, rs, lh, rh)):
            return None
        mid_shoulder = ((ls[0] + rs[0]) / 2, (ls[1] + rs[1]) / 2)
        mid_hip = ((lh[0] + rh[0]) / 2, (lh[1] + rh[1]) / 2)
        dx = mid_hip[0] - mid_shoulder[0]
        dy = mid_hip[1] - mid_shoulder[1]
        return math.degrees(math.atan2(abs(dx), abs(dy) + 1e-6))

    @staticmethod
    def _hip_y(kpts) -> float | None:
        lh, rh = kpts[L_HIP], kpts[R_HIP]
        if not all(_valid(p) for p in (lh, rh)):
            return None
        return (lh[1] + rh[1]) / 2

    @staticmethod
    def _sudden_drop(history, now) -> bool:
        recent = [e for e in history if now - e[0] <= config.FALL_WINDOW]
        if len(history) < 2 or not recent:
            return False
        oldest = history[0]
        newest = recent[-1]
        drop = newest[1] - oldest[1]  # positive => moved down in the frame
        avg_height = max((oldest[2] + newest[2]) / 2, 1.0)
        return (drop / avg_height) >= config.FALL_DROP_RATIO
