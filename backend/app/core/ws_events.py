"""Event-type constants and role groups for the WebSocket gateway — kept
separate from ws_manager.py so services can import just the constants
without pulling in the connection-management code."""

ALERT_NEW = "alert.new"
ALERT_UPDATED = "alert.updated"
CAMERA_STATUS = "camera.status"
DASHBOARD_TICK = "dashboard.tick"
SOS_TRIGGERED = "sos.triggered"
NOTIFICATION_NEW = "notification.new"

STAFF_ROLES = ["admin", "operator"]
ALL_ROLES = ["admin", "operator", "citizen"]
