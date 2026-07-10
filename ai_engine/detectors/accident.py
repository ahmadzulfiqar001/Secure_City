"""EXPERIMENTAL: motion-spike + proximity heuristic — the same technique
FightDetector uses, applied to person/vehicle pairs instead of person/person
pairs. No real collision-classifier model is used, and there's no depth
information to confirm actual contact, so this is a coarse proxy for "two
things that were close together just moved very abruptly" — mark
experimental in the UI, same as fight detection.
"""
import cv2
import numpy as np

from .. import config
from .base import AlertEvent, FrameData
from .tracker import Track


class AccidentDetector:
    def __init__(self):
        self.streak = 0

    def update(self, data: FrameData) -> list[AlertEvent]:
        hit = False
        actors = list(data.persons.values()) + [
            Track(track_id=-1, box=(x1, y1, x2, y2)) for x1, y1, x2, y2, _conf, _label in data.vehicles
        ]
        if data.prev_gray is not None and len(actors) >= 2:
            motion = cv2.absdiff(data.gray, data.prev_gray)
            for i in range(len(actors)):
                for j in range(i + 1, len(actors)):
                    if self._pair_collided(actors[i], actors[j], motion):
                        hit = True
                        break
                if hit:
                    break

        self.streak = self.streak + 1 if hit else max(self.streak - 1, 0)
        if self.streak >= config.ACCIDENT_FRAMES:
            self.streak = -config.ACCIDENT_FRAMES
            return [AlertEvent(
                "Possible Accident", "critical", confidence=0.55, experimental=True,
                details={"actor_count": len(actors)},
            )]
        return []

    @staticmethod
    def _pair_collided(a: Track, b: Track, motion: np.ndarray) -> bool:
        ax1, ay1, ax2, ay2 = a.box
        bx1, by1, bx2, by2 = b.box
        acx, acy = a.centroid
        bcx, bcy = b.centroid
        avg_w = ((ax2 - ax1) + (bx2 - bx1)) / 2
        dist = ((acx - bcx) ** 2 + (acy - bcy) ** 2) ** 0.5
        if dist > 1.0 * avg_w:
            return False
        x1 = max(int(min(ax1, bx1)), 0)
        y1 = max(int(min(ay1, by1)), 0)
        x2 = min(int(max(ax2, bx2)), motion.shape[1])
        y2 = min(int(max(ay2, by2)), motion.shape[0])
        if x2 <= x1 or y2 <= y1:
            return False
        region = motion[y1:y2, x1:x2]
        return float(region.mean()) >= config.ACCIDENT_MOTION
