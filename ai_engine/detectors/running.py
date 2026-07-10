"""Core tier: ByteTrack per-person speed (body-heights/sec) vs. thresholds."""
from .. import config
from .base import AlertEvent, FrameData


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
                "Panic Movement", "high", confidence=0.8,
                details={"runners": len(runners), "person_count": len(data.persons)},
            )]
        return [AlertEvent(
            "Person Running", "low", confidence=0.7, details={"runners": len(runners)},
        )]
