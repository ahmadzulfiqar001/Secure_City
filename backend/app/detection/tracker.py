"""Minimal centroid tracker for person boxes.

Matches detections to existing tracks by nearest centroid. Enough to
estimate per-person movement speed for the running/panic detector
without pulling in heavier tracking dependencies.
"""
import math
import time
from collections import deque
from dataclasses import dataclass, field


@dataclass
class Track:
    track_id: int
    box: tuple  # (x1, y1, x2, y2)
    misses: int = 0
    # (timestamp, cx, cy, box_height)
    history: deque = field(default_factory=lambda: deque(maxlen=30))

    @property
    def centroid(self) -> tuple:
        x1, y1, x2, y2 = self.box
        return ((x1 + x2) / 2, (y1 + y2) / 2)

    def speed(self) -> float:
        """Movement speed in body-heights per second over ~0.5 s."""
        if len(self.history) < 2:
            return 0.0
        t_now, cx_now, cy_now, h_now = self.history[-1]
        ref = None
        for entry in reversed(self.history):
            if t_now - entry[0] >= 0.4:
                ref = entry
                break
        if ref is None:
            ref = self.history[0]
        t0, cx0, cy0, h0 = ref
        dt = t_now - t0
        if dt <= 0.05:
            return 0.0
        dist = math.hypot(cx_now - cx0, cy_now - cy0)
        avg_h = max((h_now + h0) / 2, 1.0)
        return (dist / avg_h) / dt


class CentroidTracker:
    def __init__(self, max_distance: float = 80.0, max_misses: int = 10):
        self.max_distance = max_distance
        self.max_misses = max_misses
        self.tracks: dict[int, Track] = {}
        self._next_id = 1

    def update(self, boxes: list[tuple]) -> dict[int, Track]:
        now = time.time()
        unmatched = set(self.tracks.keys())

        for box in boxes:
            cx = (box[0] + box[2]) / 2
            cy = (box[1] + box[3]) / 2
            best_id, best_dist = None, self.max_distance
            for tid in unmatched:
                tcx, tcy = self.tracks[tid].centroid
                d = math.hypot(cx - tcx, cy - tcy)
                if d < best_dist:
                    best_id, best_dist = tid, d
            if best_id is not None:
                track = self.tracks[best_id]
                track.box = box
                track.misses = 0
                unmatched.discard(best_id)
            else:
                track = Track(self._next_id, box)
                self.tracks[self._next_id] = track
                self._next_id += 1
            track.history.append((now, cx, cy, box[3] - box[1]))

        for tid in list(unmatched):
            self.tracks[tid].misses += 1
            if self.tracks[tid].misses > self.max_misses:
                del self.tracks[tid]

        return {tid: t for tid, t in self.tracks.items() if t.misses == 0}
