from pydantic import BaseModel


class CameraCounts(BaseModel):
    total: int
    online: int
    offline: int
    standby: int


class AlertSeverityCounts(BaseModel):
    critical: int
    high: int
    medium: int
    low: int


class AlertCounts(BaseModel):
    total: int
    new: int
    acknowledged: int
    resolved: int
    false_positive: int
    by_severity: AlertSeverityCounts


class IncidentCounts(BaseModel):
    total: int
    open: int
    investigating: int
    resolved: int


class SOSCounts(BaseModel):
    total: int
    active: int
    resolved: int


class AnalyticsOverviewOut(BaseModel):
    cameras: CameraCounts
    alerts: AlertCounts
    incidents: IncidentCounts
    sos_events: SOSCounts
    city_safety_score: int
