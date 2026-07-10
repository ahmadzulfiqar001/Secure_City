"""Shared types every detector consumes/produces."""
from dataclasses import dataclass, field

import numpy as np

from .tracker import Track


@dataclass
class AlertEvent:
    type: str
    severity: str  # critical | high | medium | low
    confidence: float = 0.75
    experimental: bool = False   # True => heuristic standing in for a custom model
    details: dict = field(default_factory=dict)


@dataclass
class FrameData:
    frame: np.ndarray                        # BGR, resized
    gray: np.ndarray                         # grayscale of current frame
    prev_gray: np.ndarray | None             # grayscale of previous frame
    persons: dict[int, Track]                # ByteTrack-tracked person boxes, keyed by track id
    weapons: list[tuple]                     # (x1, y1, x2, y2, conf, label) — COCO proxy, fallback only
    objects: list[tuple] = field(default_factory=list)        # bags/suitcases
    pose_persons: list[tuple] = field(default_factory=list)   # (box, keypoints[17,3], conf)
    vehicles: list[tuple] = field(default_factory=list)       # (x1, y1, x2, y2, conf, label) — bicycle/car/motorcycle
    custom_weapon_boxes: list[tuple] = field(default_factory=list)      # (x1, y1, x2, y2, conf, label), custom model
    custom_fire_smoke_boxes: list[tuple] = field(default_factory=list)  # (x1, y1, x2, y2, conf, label), custom model
