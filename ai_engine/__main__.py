"""CLI entry point.

    python -m ai_engine --camera CAM-01 --source demo.mp4
    python -m ai_engine --camera CAM-01 --source 0            # USB webcam index 0
    python -m ai_engine --camera CAM-01 --source rtsp://...   # RTSP stream

`--camera` must match an existing camera's `code` in the backend (e.g. a
seeded "CAM-01") — that's where its name/lat/lng/zone/status come from.
Both flags default to SECURECITY_CAMERA_CODE / SECURECITY_SOURCE from
ai_engine/.env if omitted.
"""
import argparse
import logging

from . import config
from .pipeline import Pipeline


def main() -> None:
    parser = argparse.ArgumentParser(prog="python -m ai_engine", description="SecureCity AI detection worker")
    parser.add_argument("--camera", default=config.DEFAULT_CAMERA_CODE, help="backend camera code, e.g. CAM-01")
    parser.add_argument("--source", default=config.DEFAULT_SOURCE, help="webcam index, video file path, or rtsp:// URL")
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"])
    args = parser.parse_args()

    logging.basicConfig(level=getattr(logging, args.log_level), format="%(asctime)s %(levelname)s %(name)s: %(message)s")

    if args.source in (None, "", "none"):
        raise SystemExit("--source is required (a webcam index, video file path, or rtsp:// URL) — refusing to guess one")

    Pipeline(source=args.source, camera_code=args.camera).run()


if __name__ == "__main__":
    main()
