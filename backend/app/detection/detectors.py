"""Alert detectors. Each consumes one FrameData and yields AlertEvents.

Weapon detection uses YOLO classes directly. Fight, running/panic and
overcrowding are heuristic (motion + tracking based) — acceptable for the
prototype scope and swappable with trained action-recognition models later.
"""
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


def build_detectors() -> list:
    return [WeaponDetector(), FightDetector(), RunningDetector(), CrowdDetector()]
