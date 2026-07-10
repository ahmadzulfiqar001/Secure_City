from .base import AlertEvent, FrameData
from .abandoned import AbandonedObjectDetector
from .accident import AccidentDetector
from .crowd import CrowdDetector
from .fall import FallDetector
from .fight import FightDetector
from .fire_smoke import CustomFireSmokeDetector, FireSmokeDetector
from .loiter import LoiteringDetector
from .running import RunningDetector
from .weapon import CustomWeaponDetector, WeaponDetector
from .zone import RestrictedZoneDetector


def build_detectors(
    zone_polygon: list[list[float]] | None = None,
    weapon_model_loaded: bool = False,
    fire_smoke_model_loaded: bool = False,
) -> list:
    """Every detector currently wired into the pipeline, in the order
    they're evaluated each frame. See config.py for what's a real
    (Core-tier) technique vs an experimental heuristic standing in for a
    custom-trained model. `zone_polygon` is this camera's restricted-zone
    config fetched from the backend — None means no zone is configured for
    the camera and the intrusion detector stays a no-op. `weapon_model_loaded`
    / `fire_smoke_model_loaded` pick the real trained detector over the
    experimental fallback once the matching weights file exists — see
    Pipeline.run()."""
    weapon_detector = CustomWeaponDetector() if weapon_model_loaded else WeaponDetector()
    fire_smoke_detector = CustomFireSmokeDetector() if fire_smoke_model_loaded else FireSmokeDetector()
    return [
        weapon_detector,
        FightDetector(),
        AccidentDetector(),
        RunningDetector(),
        CrowdDetector(),
        fire_smoke_detector,
        FallDetector(),
        RestrictedZoneDetector(zone_polygon),
        AbandonedObjectDetector(),
        LoiteringDetector(),
    ]


__all__ = [
    "AlertEvent",
    "FrameData",
    "AbandonedObjectDetector",
    "AccidentDetector",
    "CrowdDetector",
    "CustomFireSmokeDetector",
    "CustomWeaponDetector",
    "FallDetector",
    "FightDetector",
    "FireSmokeDetector",
    "LoiteringDetector",
    "RunningDetector",
    "WeaponDetector",
    "RestrictedZoneDetector",
    "build_detectors",
]
