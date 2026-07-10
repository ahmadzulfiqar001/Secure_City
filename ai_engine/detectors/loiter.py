"""Core tier: ByteTrack track-ID dwell-time threshold in a small radius —
a person who drifts less than `config.LOITER_MOVE_RADIUS` px for
`config.LOITER_SECONDS` gets flagged once (resets if they move away or
leave the frame)."""
import math
import time

from .. import config
from .base import AlertEvent, FrameData


class LoiteringDetector:
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
                    "Suspicious Loitering", "low", confidence=0.65,
                    details={"track_id": tid, "seconds": round(now - o["first_seen"], 1)},
                ))
        return events
