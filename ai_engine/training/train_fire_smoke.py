"""Trains a custom fire/smoke-detection YOLOv8 model and exports it to
ai_engine/weights/fire_smoke_best.pt, where Pipeline.run() picks it up
automatically (see config.FIRE_SMOKE_MODEL_PATH). Until this file exists,
the pipeline logs a warning and keeps using the experimental HSV-heuristic
FireSmokeDetector instead — see detectors/fire_smoke.py.

## Choosing a dataset

Search Roboflow Universe (universe.roboflow.com) for "fire smoke detection"
or "fire and smoke detection" — this is a common, well-represented category
there with multiple actively-maintained public datasets. Same selection
criteria as the weapon model (see train_weapon.py's docstring): Object
Detection type, a YOLOv8 export option, enough images to generalize.

IMPORTANT — class names must match: CustomFireSmokeDetector (see
detectors/fire_smoke.py) looks for boxes whose class name is exactly
"fire" or "smoke" (lowercase). Most fire/smoke datasets on Roboflow
Universe already use these names, but open the downloaded data.yaml's
`names:` list and confirm before training — if the dataset uses different
names (e.g. "Fire", "Smoke-Detection"), either pick a different dataset or
rename the classes in data.yaml before training.

## Usage

    python -m ai_engine.training.train_fire_smoke \\
        --api-key YOUR_ROBOFLOW_KEY \\
        --workspace WORKSPACE_SLUG \\
        --project PROJECT_SLUG \\
        --version 1 \\
        --epochs 50

Needs `pip install roboflow` (see ai_engine/requirements.txt).
"""
import argparse
import logging

from .. import config
from .common import download_roboflow_dataset, export_weights, train_yolov8

log = logging.getLogger("ai_engine.training.fire_smoke")


def main() -> None:
    parser = argparse.ArgumentParser(description="Train the custom fire/smoke-detection model")
    parser.add_argument("--api-key", required=True, help="Roboflow API key (app.roboflow.com/settings/api)")
    parser.add_argument("--workspace", required=True, help="Roboflow workspace slug")
    parser.add_argument("--project", required=True, help="Roboflow project slug")
    parser.add_argument("--version", type=int, required=True, help="Roboflow dataset version number")
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--imgsz", type=int, default=640)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")

    dataset_dir = download_roboflow_dataset(
        args.api_key, args.workspace, args.project, args.version,
        dest_dir=config.BASE_DIR / "training" / "datasets" / "fire_smoke",
    )
    data_yaml = dataset_dir / "data.yaml"
    if not data_yaml.exists():
        raise SystemExit(f"expected {data_yaml} after download — check the dataset actually exported in YOLOv8 format")

    import yaml
    names = yaml.safe_load(data_yaml.read_text()).get("names", [])
    lower_names = {str(n).lower() for n in (names.values() if isinstance(names, dict) else names)}
    if not {"fire", "smoke"} & lower_names:
        log.warning(
            "dataset classes are %s — CustomFireSmokeDetector expects 'fire'/'smoke' exactly. "
            "Training will proceed but detections may not map to alerts until you fix data.yaml's names.",
            sorted(lower_names),
        )

    best = train_yolov8(data_yaml, args.epochs, args.imgsz, run_name="fire_smoke")
    export_weights(best, config.FIRE_SMOKE_MODEL_PATH)


if __name__ == "__main__":
    main()
