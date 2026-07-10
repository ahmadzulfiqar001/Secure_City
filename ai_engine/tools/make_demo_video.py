"""Regenerates ai_engine/videos/demo_bus_stop.mp4 — a real test clip made
by looping ultralytics' own bundled bus.jpg (ships with the pip package,
several real photographed pedestrians) as a static-camera feed. No network
fetch, no synthetic shapes; videos/ is gitignored so this script is how to
get the clip back after a fresh clone.

    python -m ai_engine.tools.make_demo_video
"""
import os

import cv2
import ultralytics

from .. import config


def main() -> None:
    src = os.path.join(os.path.dirname(ultralytics.__file__), "assets", "bus.jpg")
    img = cv2.imread(src)
    h, w = img.shape[:2]
    scale = 640 / w
    img = cv2.resize(img, (640, int(h * scale)))

    out_path = config.VIDEO_DIR / "demo_bus_stop.mp4"
    fps, seconds = 5, 40
    writer = cv2.VideoWriter(str(out_path), cv2.VideoWriter_fourcc(*"mp4v"), fps, (img.shape[1], img.shape[0]))
    for _ in range(fps * seconds):
        writer.write(img)
    writer.release()
    print(f"wrote {out_path}: {img.shape[1]}x{img.shape[0]} @ {fps}fps, {seconds}s ({fps * seconds} frames)")


if __name__ == "__main__":
    main()
