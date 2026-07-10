"""Core tier: person count per zone/frame vs. a threshold."""
from .. import config
from .base import AlertEvent, FrameData


class CrowdDetector:
    def update(self, data: FrameData) -> list[AlertEvent]:
        count = len(data.persons)
        if count >= config.CROWD_THRESHOLD:
            return [AlertEvent(
                "Overcrowding", "medium", confidence=0.9,
                details={"person_count": count},
            )]
        return []
