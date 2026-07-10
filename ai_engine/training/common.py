"""Shared Roboflow-download + YOLOv8-train + weights-export plumbing for
train_weapon.py and train_fire_smoke.py. See training/README.md for how to
pick a dataset and fill in the placeholders each script asks for.
"""
import logging
import shutil
from pathlib import Path

log = logging.getLogger("ai_engine.training")


def download_roboflow_dataset(api_key: str, workspace: str, project: str, version: int, dest_dir: Path) -> Path:
    """Downloads a Roboflow dataset in YOLOv8 format. Requires the
    `roboflow` package (`pip install roboflow`) and a real API key from
    https://app.roboflow.com/settings/api — free tier is enough for a
    small FYP-scale dataset."""
    from roboflow import Roboflow

    log.info("downloading %s/%s v%d from Roboflow...", workspace, project, version)
    rf = Roboflow(api_key=api_key)
    ds = rf.workspace(workspace).project(project).version(version).download("yolov8", location=str(dest_dir))
    log.info("dataset downloaded to %s", ds.location)
    return Path(ds.location)


def train_yolov8(data_yaml: Path, epochs: int, imgsz: int, run_name: str) -> Path:
    """Fine-tunes a YOLOv8n checkpoint on the downloaded dataset. Returns
    the path to the resulting best.pt. Starting from yolov8n.pt (not
    from scratch) is deliberate — transfer learning from COCO gets a
    usable model from a few hundred to a few thousand labeled images,
    which is the realistic dataset size for a Roboflow Universe pull,
    versus the tens of thousands of images training from scratch needs."""
    from ultralytics import YOLO

    model = YOLO("yolov8n.pt")
    results = model.train(data=str(data_yaml), epochs=epochs, imgsz=imgsz, name=run_name)
    best = Path(results.save_dir) / "weights" / "best.pt"
    if not best.exists():
        raise FileNotFoundError(f"training finished but {best} wasn't produced — check the run's output above")
    return best


def export_weights(best_pt: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(best_pt, dest)
    log.info("weights exported to %s", dest)
    log.info("restart the pipeline (python -m ai_engine ...) — it picks this up automatically at startup.")
