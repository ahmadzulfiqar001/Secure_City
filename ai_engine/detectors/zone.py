"""Core tier: `supervision.PolygonZone` + ByteTrack-tracked persons.

Alerts when a tracked person's bottom-center anchor enters the camera's
configured restricted zone — a polygon in fractional (0-1) frame
coordinates, fetched from the backend's per-camera config (Camera.zone,
set via `PUT /api/v1/cameras/{id}`) rather than hardcoded here, per the
"zones stored in camera config" requirement.
"""
import numpy as np
import supervision as sv

from .. import config
from .base import AlertEvent, FrameData


class RestrictedZoneDetector:
    def __init__(self, zone_polygon: list[list[float]] | None = None):
        self.streak = 0
        self._zone_polygon = zone_polygon  # fractional (0-1) [x, y] points, or None => no zone configured
        self._zone: sv.PolygonZone | None = None
        self._zone_frame_size: tuple[int, int] | None = None

    def _get_zone(self, frame_w: int, frame_h: int) -> sv.PolygonZone:
        if self._zone is None or self._zone_frame_size != (frame_w, frame_h):
            polygon = np.array(
                [(int(px * frame_w), int(py * frame_h)) for px, py in self._zone_polygon],
                dtype=np.int64,
            )
            self._zone = sv.PolygonZone(polygon=polygon, triggering_anchors=(sv.Position.BOTTOM_CENTER,))
            self._zone_frame_size = (frame_w, frame_h)
        return self._zone

    def update(self, data: FrameData) -> list[AlertEvent]:
        if not self._zone_polygon:
            return []  # this camera has no restricted zone configured

        h, w = data.frame.shape[:2]
        zone = self._get_zone(w, h)

        if data.persons:
            ids = list(data.persons.keys())
            xyxy = np.array([data.persons[tid].box for tid in ids], dtype=np.float32)
            detections = sv.Detections(xyxy=xyxy, tracker_id=np.array(ids))
            inside_mask = zone.trigger(detections)
            intruders = int(inside_mask.sum())
        else:
            intruders = 0

        # Re-arming hysteresis (same pattern as FireSmokeDetector) — someone
        # lingering in the zone keeps re-alerting, cooldown-limited by the
        # pipeline, instead of firing once and going quiet for their visit.
        self.streak = self.streak + 1 if intruders > 0 else max(self.streak - 1, 0)
        if self.streak >= config.ZONE_FRAMES:
            self.streak = -config.ZONE_FRAMES
            return [AlertEvent(
                "Restricted Area Intrusion", "medium", confidence=0.9,
                details={"intruders": intruders},
            )]
        return []
