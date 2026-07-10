from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..models import Alert, Camera, Incident, SOSEvent


class AnalyticsRepository:
    def __init__(self, db: Session):
        self.db = db

    def camera_counts(self) -> dict:
        total = self.db.scalar(select(func.count()).select_from(Camera)) or 0
        rows = self.db.execute(select(Camera.status, func.count()).group_by(Camera.status)).all()
        by_status = {status: count for status, count in rows}
        return {
            "total": total,
            "online": by_status.get("online", 0),
            "offline": by_status.get("offline", 0),
            "standby": by_status.get("standby", 0),
        }

    def alert_counts(self) -> dict:
        total = self.db.scalar(select(func.count()).select_from(Alert)) or 0
        acknowledged = self.db.scalar(select(func.count()).select_from(Alert).where(Alert.acknowledged.is_(True))) or 0
        resolved = self.db.scalar(select(func.count()).select_from(Alert).where(Alert.resolved.is_(True))) or 0
        false_positive = self.db.scalar(select(func.count()).select_from(Alert).where(Alert.false_positive.is_(True))) or 0
        new = self.db.scalar(
            select(func.count()).select_from(Alert).where(
                Alert.acknowledged.is_(False), Alert.resolved.is_(False), Alert.false_positive.is_(False)
            )
        ) or 0
        rows = self.db.execute(select(Alert.severity, func.count()).group_by(Alert.severity)).all()
        by_severity = {severity: count for severity, count in rows}
        return {
            "total": total,
            "new": new,
            "acknowledged": acknowledged,
            "resolved": resolved,
            "false_positive": false_positive,
            "by_severity": {
                "critical": by_severity.get("critical", 0),
                "high": by_severity.get("high", 0),
                "medium": by_severity.get("medium", 0),
                "low": by_severity.get("low", 0),
            },
        }

    def open_alert_severity_counts(self) -> dict:
        """Severity breakdown of alerts still open (not resolved, not
        flagged false-positive) — what the city safety score is computed
        from, as opposed to `alert_counts()['by_severity']` which counts
        every alert ever, regardless of status."""
        rows = self.db.execute(
            select(Alert.severity, func.count())
            .where(Alert.resolved.is_(False), Alert.false_positive.is_(False))
            .group_by(Alert.severity)
        ).all()
        by_severity = {severity: count for severity, count in rows}
        return {
            "critical": by_severity.get("critical", 0),
            "high": by_severity.get("high", 0),
            "medium": by_severity.get("medium", 0),
            "low": by_severity.get("low", 0),
        }

    def incident_counts(self) -> dict:
        total = self.db.scalar(select(func.count()).select_from(Incident)) or 0
        rows = self.db.execute(select(Incident.status, func.count()).group_by(Incident.status)).all()
        by_status = {status: count for status, count in rows}
        return {
            "total": total,
            "open": by_status.get("open", 0),
            "investigating": by_status.get("investigating", 0),
            "resolved": by_status.get("resolved", 0),
        }

    def sos_counts(self) -> dict:
        total = self.db.scalar(select(func.count()).select_from(SOSEvent)) or 0
        rows = self.db.execute(select(SOSEvent.status, func.count()).group_by(SOSEvent.status)).all()
        by_status = {status: count for status, count in rows}
        return {
            "total": total,
            "active": by_status.get("active", 0),
            "resolved": by_status.get("resolved", 0),
        }
