"""Per-track history/speed bookkeeping.

Track *identity* now comes from Ultralytics' built-in ByteTrack
(`model.track(..., tracker="bytetrack.yaml")`) — this module no longer does
its own centroid-matching (that was a stand-in before ByteTrack was wired
in). What's left is genuinely still needed: turning a bare box into a
short position history so detectors can ask "how fast is this track
moving" or "how long has it been roughly still".
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
    history: deque = field(default_factory=lambda: deque(maxlen=30))  # (ts, cx, cy, height)

    @property
    def centroid(self) -> tuple:
        x1, y1, x2, y2 = self.box
        return ((x1 + x2) / 2, (y1 + y2) / 2)

    def speed(self) -> float:
        """Movement speed in body-heights per second over ~0.4 s."""
        if len(self.history) < 2:
            return 0.0
        t_now, cx_now, cy_now, h_now = self.history[-1]
        ref = self.history[0]
        for entry in reversed(self.history):
            if t_now - entry[0] >= 0.4:
                ref = entry
                break
        t0, cx0, cy0, h0 = ref
        dt = t_now - t0
        if dt <= 0.05:
            return 0.0
        dist = math.hypot(cx_now - cx0, cy_now - cy0)
        avg_h = max((h_now + h0) / 2, 1.0)
        return (dist / avg_h) / dt


class TrackStore:
    """Keyed by the track id ByteTrack assigns — just prunes tracks that
    ByteTrack stopped reporting and appends position history for the rest."""

    def __init__(self, max_misses: int = 10):
        self.max_misses = max_misses
        self.tracks: dict[int, Track] = {}

    def update(self, boxes_by_id: dict[int, tuple]) -> dict[int, Track]:
        now = time.time()
        for tid, box in boxes_by_id.items():
            cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
            track = self.tracks.get(tid)
            if track is None:
                track = Track(tid, box)
                self.tracks[tid] = track
            else:
                track.box = box
            track.misses = 0
            track.history.append((now, cx, cy, box[3] - box[1]))

        for tid in list(self.tracks.keys()):
            if tid not in boxes_by_id:
                self.tracks[tid].misses += 1
                if self.tracks[tid].misses > self.max_misses:
                    del self.tracks[tid]

        return {tid: t for tid, t in self.tracks.items() if t.misses == 0}
