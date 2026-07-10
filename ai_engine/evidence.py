"""Evidence capture: face-blurred snapshots, and a rolling short clip buffer
so a high-severity alert can be saved with ~N seconds of context around it.
"""
import time
from collections import deque

import cv2
import numpy as np

from . import config


class FaceBlurrer:
    """Real-time face blur via OpenCV's bundled Haar cascade — no custom
    model needed. Applied before any frame is saved or streamed anywhere,
    so evidence never contains identifiable faces."""

    def __init__(self, enabled: bool = config.FACE_BLUR_ENABLED):
        self.enabled = enabled
        self._cascade = (
            cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")
            if enabled
            else None
        )

    def apply(self, frame: np.ndarray, gray: np.ndarray) -> None:
        """Blurs faces in `frame` in place."""
        if self._cascade is None:
            return
        faces = self._cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(24, 24))
        for (x, y, w, h) in faces:
            roi = frame[y:y + h, x:x + w]
            if roi.size == 0:
                continue
            frame[y:y + h, x:x + w] = cv2.GaussianBlur(roi, (0, 0), sigmaX=15)


class ClipBuffer:
    """Keeps the last `config.CLIP_SECONDS` of (already face-blurred)
    frames in memory so a fired alert can save a short evidence clip
    without needing to have started recording in advance."""

    def __init__(self):
        self._frames: deque[tuple[float, np.ndarray]] = deque()

    def push(self, frame: np.ndarray) -> None:
        now = time.time()
        self._frames.append((now, frame.copy()))
        while self._frames and now - self._frames[0][0] > config.CLIP_SECONDS:
            self._frames.popleft()

    def save_clip(self, name: str) -> str | None:
        if not self._frames:
            return None
        path = config.CLIP_DIR / name
        h, w = self._frames[0][1].shape[:2]
        writer = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), config.CLIP_FPS, (w, h))
        for _, frame in self._frames:
            writer.write(frame)
        writer.release()
        return name


def save_snapshot(frame: np.ndarray, name: str) -> str:
    cv2.imwrite(str(config.SNAPSHOT_DIR / name), frame)
    return name
