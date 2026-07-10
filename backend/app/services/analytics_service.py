from sqlalchemy.orm import Session

from ..repositories.analytics_repository import AnalyticsRepository
from ..schemas.analytics import (
    AlertCounts,
    AlertSeverityCounts,
    AnalyticsOverviewOut,
    CameraCounts,
    IncidentCounts,
    SOSCounts,
)


class AnalyticsService:
    def __init__(self, db: Session):
        self.analytics = AnalyticsRepository(db)

    def overview(self) -> AnalyticsOverviewOut:
        cameras = self.analytics.camera_counts()
        alerts = self.analytics.alert_counts()
        incidents = self.analytics.incident_counts()
        sos = self.analytics.sos_counts()
        open_severity = self.analytics.open_alert_severity_counts()
        return AnalyticsOverviewOut(
            cameras=CameraCounts(**cameras),
            alerts=AlertCounts(
                total=alerts["total"], new=alerts["new"], acknowledged=alerts["acknowledged"],
                resolved=alerts["resolved"], false_positive=alerts["false_positive"],
                by_severity=AlertSeverityCounts(**alerts["by_severity"]),
            ),
            incidents=IncidentCounts(**incidents),
            sos_events=SOSCounts(**sos),
            city_safety_score=self._city_safety_score(cameras, open_severity),
        )

    @staticmethod
    def _city_safety_score(cameras: dict, open_severity: dict) -> int:
        """100, minus a weighted penalty per open alert by severity, minus a
        penalty for the proportion of cameras currently offline."""
        score = 100
        score -= open_severity["critical"] * 15
        score -= open_severity["high"] * 10
        score -= open_severity["medium"] * 5
        score -= open_severity["low"] * 2
        if cameras["total"] > 0:
            score -= round(cameras["offline"] / cameras["total"] * 15)
        return max(0, min(100, score))
