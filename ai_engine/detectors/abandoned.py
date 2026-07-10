"""Core tier: COCO backpack/handbag/suitcase detections tracked with a
lightweight dwell-time tracker (separate from the person ByteTrack space —
dwell time needs longer memory than a few dozen frames). Fires once an
object has sat within a small radius, with no person nearby, for
`config.ABANDON_SECONDS`.
"""
import math
import time

from .. import config
from .base import AlertEvent, FrameData


class AbandonedObjectDetector:
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
                    "Abandoned Object", "medium", confidence=0.75,
                    details={"object": o["label"], "dwell_seconds": round(now - o["first_seen"], 1)},
                ))
        return events
