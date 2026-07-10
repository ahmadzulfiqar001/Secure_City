"""Two implementations, picked by build_detectors() based on whether
WEAPON_MODEL_PATH exists:

- WeaponDetector: EXPERIMENTAL fallback. No Roboflow-trained gun/knife
  model is wired up — flags COCO classes that are plausible weapon proxies
  (baseball bat, knife, scissors) so the alert pipeline can be demoed end
  to end without one. See training/train_weapon.py.
- CustomWeaponDetector: wraps a real trained weapon-detection model's
  output (Pipeline runs it as a separate inference pass, same pattern as
  the pose model) — not experimental, since it's a real trained detector.
"""
from .base import AlertEvent, FrameData


class WeaponDetector:
    def update(self, data: FrameData) -> list[AlertEvent]:
        if not data.weapons:
            return []
        labels = sorted({w[5] for w in data.weapons})
        best_conf = max(w[4] for w in data.weapons)
        return [AlertEvent(
            "Weapon Detected", "critical", confidence=round(best_conf, 2), experimental=True,
            details={"objects": labels, "count": len(data.weapons)},
        )]


class CustomWeaponDetector:
    def update(self, data: FrameData) -> list[AlertEvent]:
        if not data.custom_weapon_boxes:
            return []
        labels = sorted({w[5] for w in data.custom_weapon_boxes})
        best_conf = max(w[4] for w in data.custom_weapon_boxes)
        return [AlertEvent(
            "Weapon Detected", "critical", confidence=round(best_conf, 2), experimental=False,
            details={"objects": labels, "count": len(data.custom_weapon_boxes), "model": "custom"},
        )]
