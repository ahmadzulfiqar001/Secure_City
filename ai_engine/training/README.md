# Custom model training

Two detectors have a real-model path and an experimental-heuristic
fallback path:

| Detector | Fallback (always available) | Real model (needs training) |
|---|---|---|
| Weapon | `WeaponDetector` — COCO classes (bat/knife/scissors) as proxies, `experimental=true` | `CustomWeaponDetector` — `weights/weapon_best.pt` |
| Fire/Smoke | `FireSmokeDetector` — HSV color heuristic, `experimental=true` | `CustomFireSmokeDetector` — `weights/fire_smoke_best.pt` |

`Pipeline.run()` checks for the weights file at startup. If it's missing,
it logs a warning and keeps running on the fallback detector — the engine
never crashes or refuses to start for lack of a trained model. If it's
present, it loads it and switches to the non-experimental detector.

## Why Roboflow

Roboflow Universe (universe.roboflow.com) hosts thousands of
community-published, pre-labeled datasets with a one-line export to
YOLOv8 format, and a free API tier — the realistic option for training a
custom detector without collecting/labeling images yourself, which is
out of scope for this FYP's timeline.

## Training

Both `training/train_weapon.py` and `training/train_fire_smoke.py`:

1. Download a dataset you choose from Roboflow Universe (see each script's
   own docstring for how to pick one and where to find the
   `--workspace`/`--project`/`--version` values Roboflow gives you).
2. Fine-tune a `yolov8n.pt` checkpoint on it (transfer learning — realistic
   for the few-hundred-to-few-thousand-image datasets you'll actually find,
   versus training from scratch which needs far more data).
3. Copy the resulting `best.pt` to `ai_engine/weights/weapon_best.pt` or
   `ai_engine/weights/fire_smoke_best.pt`.

```
pip install -r ai_engine/requirements.txt   # includes roboflow

python -m ai_engine.training.train_weapon \
    --api-key <your Roboflow key> --workspace <slug> --project <slug> --version 1 --epochs 50

python -m ai_engine.training.train_fire_smoke \
    --api-key <your Roboflow key> --workspace <slug> --project <slug> --version 1 --epochs 50
```

No GPU is required, but training on CPU is slow — use `--epochs 5` first
to confirm the whole pipeline (download → train → export) works end to
end before committing to a full run.

## Fire/smoke class-name requirement

`CustomFireSmokeDetector` matches boxes by class name, expecting exactly
`fire` and `smoke` (lowercase — see `detectors/fire_smoke.py`). Check the
downloaded dataset's `data.yaml` `names:` list before training; the script
warns (but doesn't block) if it doesn't see either name.

## Confidence tuning

Once real weights exist, tune `CONFIDENCE_THRESHOLDS["weapon_custom"]` /
`["fire_custom"]` / `["smoke_custom"]` in `ai_engine/config.py` against
your own validation clips — a custom-trained model's useful confidence
cutoff depends on how the dataset was labeled and is worth checking
empirically rather than trusting the fallback heuristics' tuned values.
