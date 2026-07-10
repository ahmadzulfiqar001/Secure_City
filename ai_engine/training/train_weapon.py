"""Trains a custom weapon-detection YOLOv8 model and exports it to
ai_engine/weights/weapon_best.pt, where Pipeline.run() picks it up
automatically (see config.WEAPON_MODEL_PATH). Until this file exists, the
pipeline logs a warning and keeps using the experimental COCO-proxy
WeaponDetector instead — see detectors/weapon.py.

## Choosing a dataset

This script downloads a dataset from Roboflow Universe (universe.roboflow.com)
rather than hardcoding one specific project, because the "best" weapon
dataset changes over time and you should look at what you're training on
before committing to it. To pick one:

1. Go to Roboflow Universe and search "weapon detection" (or "gun detection",
   "knife detection" — narrower datasets are often cleaner than broad ones).
2. Filter to Object Detection type. Prefer a dataset with:
   - At least ~1000 images (a few hundred works for an FYP demo, but expect
     more false positives/negatives the smaller it is).
   - Classes that match what you actually want to alert on (e.g. "pistol",
     "knife" — check the dataset's class list on its page before downloading).
   - A "YOLOv8" export option (most do — Roboflow generates this on demand).
3. On the dataset's page: Download Dataset -> format "YOLOv8" -> "show download code"
   gives you the exact workspace slug, project slug, and version number to
   pass below (it's literally in the `rf.workspace("...").project("...").version(N)`
   snippet Roboflow generates for you).
4. Get a free API key from https://app.roboflow.com/settings/api.

## Usage

    python -m ai_engine.training.train_weapon \\
        --api-key YOUR_ROBOFLOW_KEY \\
        --workspace WORKSPACE_SLUG_FROM_STEP_3 \\
        --project PROJECT_SLUG_FROM_STEP_3 \\
        --version 1 \\
        --epochs 50

Needs `pip install roboflow` (see ai_engine/requirements.txt) and either a
GPU or patience — 50 epochs on a few thousand images takes minutes on a
GPU, hours on CPU. Lower --epochs for a quick smoke test of the pipeline.
"""
import argparse
import logging
from pathlib import Path

from .. import config
from .common import download_roboflow_dataset, export_weights, train_yolov8

log = logging.getLogger("ai_engine.training.weapon")


def main() -> None:
    parser = argparse.ArgumentParser(description="Train the custom weapon-detection model")
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
        dest_dir=config.BASE_DIR / "training" / "datasets" / "weapon",
    )
    data_yaml = dataset_dir / "data.yaml"
    if not data_yaml.exists():
        raise SystemExit(f"expected {data_yaml} after download — check the dataset actually exported in YOLOv8 format")

    best = train_yolov8(data_yaml, args.epochs, args.imgsz, run_name="weapon")
    export_weights(best, config.WEAPON_MODEL_PATH)


if __name__ == "__main__":
    main()
