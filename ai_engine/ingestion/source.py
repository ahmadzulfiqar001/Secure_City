"""Video source abstraction — webcam, video file, or RTSP stream.

Kept intentionally thin: OpenCV's VideoCapture already understands all
three (an int/numeric string for a local camera index, a file path, or an
rtsp:// URL) — this class just gives the pipeline one honest `is_file`
flag (so it knows whether to loop on EOF) and a uniform open/read/release
API regardless of which kind of source it is.
"""
import cv2


class VideoSource:
    def __init__(self, source: str):
        self.source = source
        self.is_file = not source.isdigit() and not source.startswith("rtsp://")
        self._cap: cv2.VideoCapture | None = None

    def open(self) -> bool:
        target = int(self.source) if self.source.isdigit() else self.source
        self._cap = cv2.VideoCapture(target)
        return bool(self._cap and self._cap.isOpened())

    def read(self):
        if self._cap is None:
            return False, None
        ok, frame = self._cap.read()
        if not ok and self.is_file:
            self._cap.set(cv2.CAP_PROP_POS_FRAMES, 0)  # loop video files for continuous demo
            ok, frame = self._cap.read()
        return ok, frame

    def release(self) -> None:
        if self._cap is not None:
            self._cap.release()
            self._cap = None
