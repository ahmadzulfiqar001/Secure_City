"""STRETCH tier (per spec A3): motion-spike + proximity heuristic only —
mark experimental in the UI. No real action-recognition model is used."""
import cv2
import numpy as np

from .. import config
from .base import AlertEvent, FrameData
from .tracker import Track


class FightDetector:
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
            self.streak = -config.FIGHT_FRAMES
            return [AlertEvent(
                "Fight Detected", "critical", confidence=0.6, experimental=True,
                details={"person_count": len(data.persons)},
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
