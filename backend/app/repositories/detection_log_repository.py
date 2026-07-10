import json

from sqlalchemy.orm import Session

from ..models import DetectionLog


class DetectionLogRepository:
    def __init__(self, db: Session):
        self.db = db

    def bulk_create(self, camera_id: int | None, rows: list[dict]) -> int:
        for row in rows:
            self.db.add(DetectionLog(
                camera_id=camera_id,
                model_name=row["model_name"],
                class_name=row["class_name"],
                confidence=row["confidence"],
                track_id=row.get("track_id"),
                bbox=json.dumps(row["bbox"]) if row.get("bbox") else None,
            ))
        self.db.commit()
        return len(rows)
