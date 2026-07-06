"""SQLite alert store. Thread-safe via a module-level lock.

SQLite keeps the prototype zero-config; the functions below are the only
storage touchpoints, so swapping in MongoDB later means reimplementing
just this module.
"""
import json
import sqlite3
import threading
from datetime import datetime, timezone

from . import config

_lock = threading.Lock()
_conn: sqlite3.Connection | None = None


def _get_conn() -> sqlite3.Connection:
    global _conn
    if _conn is None:
        _conn = sqlite3.connect(config.DB_PATH, check_same_thread=False)
        _conn.row_factory = sqlite3.Row
    return _conn


def _ensure_column(conn: sqlite3.Connection, table: str, column: str, coltype: str) -> None:
    existing = {row["name"] for row in conn.execute(f"PRAGMA table_info({table})")}
    if column not in existing:
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {coltype}")


def init_db() -> None:
    with _lock:
        conn = _get_conn()
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS alerts (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                type        TEXT NOT NULL,
                severity    TEXT NOT NULL,
                camera_id   TEXT NOT NULL,
                camera_name TEXT NOT NULL,
                lat         REAL,
                lng         REAL,
                ts          TEXT NOT NULL,
                snapshot    TEXT,
                details     TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                name          TEXT NOT NULL,
                email         TEXT NOT NULL UNIQUE,
                phone         TEXT,
                password_hash TEXT NOT NULL,
                created_at    TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS emergency_contacts (
                id       INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id  INTEGER NOT NULL,
                name     TEXT NOT NULL,
                relation TEXT NOT NULL,
                phone    TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users (id)
            )
            """
        )
        # Migrations for columns added after the table first shipped.
        _ensure_column(conn, "users", "verified", "INTEGER NOT NULL DEFAULT 0")
        _ensure_column(conn, "users", "otp_code", "TEXT")
        _ensure_column(conn, "users", "otp_purpose", "TEXT")
        _ensure_column(conn, "users", "otp_expires", "TEXT")
        _ensure_column(conn, "users", "preferences", "TEXT")
        _ensure_column(conn, "alerts", "acknowledged", "INTEGER NOT NULL DEFAULT 0")
        _ensure_column(conn, "alerts", "resolved", "INTEGER NOT NULL DEFAULT 0")
        conn.commit()


# ── users ────────────────────────────────────────────────────────────
def create_user(name: str, email: str, phone: str, password_hash: str) -> dict:
    ts = datetime.now(timezone.utc).isoformat()
    with _lock:
        cur = _get_conn().execute(
            "INSERT INTO users (name, email, phone, password_hash, created_at) VALUES (?, ?, ?, ?, ?)",
            (name, email.lower().strip(), phone, password_hash, ts),
        )
        _get_conn().commit()
        user_id = cur.lastrowid
    return get_user_by_id(user_id)


def get_user_by_email(email: str) -> dict | None:
    with _lock:
        row = _get_conn().execute(
            "SELECT * FROM users WHERE email = ?", (email.lower().strip(),)
        ).fetchone()
    return dict(row) if row else None


def get_user_by_id(user_id: int) -> dict | None:
    with _lock:
        row = _get_conn().execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    return dict(row) if row else None


def set_otp(user_id: int, code: str, purpose: str, expires_iso: str) -> None:
    with _lock:
        _get_conn().execute(
            "UPDATE users SET otp_code = ?, otp_purpose = ?, otp_expires = ? WHERE id = ?",
            (code, purpose, expires_iso, user_id),
        )
        _get_conn().commit()


def clear_otp(user_id: int) -> None:
    with _lock:
        _get_conn().execute(
            "UPDATE users SET otp_code = NULL, otp_purpose = NULL, otp_expires = NULL WHERE id = ?",
            (user_id,),
        )
        _get_conn().commit()


def mark_verified(user_id: int) -> None:
    with _lock:
        _get_conn().execute("UPDATE users SET verified = 1 WHERE id = ?", (user_id,))
        _get_conn().commit()


def update_profile(user_id: int, name: str, phone: str) -> dict:
    with _lock:
        _get_conn().execute(
            "UPDATE users SET name = ?, phone = ? WHERE id = ?", (name, phone, user_id)
        )
        _get_conn().commit()
    return get_user_by_id(user_id)


def update_password(user_id: int, password_hash: str) -> None:
    with _lock:
        _get_conn().execute(
            "UPDATE users SET password_hash = ? WHERE id = ?", (password_hash, user_id)
        )
        _get_conn().commit()


def delete_user(user_id: int) -> None:
    with _lock:
        _get_conn().execute("DELETE FROM users WHERE id = ?", (user_id,))
        _get_conn().commit()


def insert_alert(
    type_: str,
    severity: str,
    camera: dict,
    snapshot: str | None = None,
    details: dict | None = None,
) -> dict:
    ts = datetime.now(timezone.utc).isoformat()
    with _lock:
        cur = _get_conn().execute(
            "INSERT INTO alerts (type, severity, camera_id, camera_name, lat, lng, ts, snapshot, details)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                type_,
                severity,
                camera["id"],
                camera["name"],
                camera["lat"],
                camera["lng"],
                ts,
                snapshot,
                json.dumps(details or {}),
            ),
        )
        _get_conn().commit()
        alert_id = cur.lastrowid
    return get_alert(alert_id)


def _row_to_dict(row: sqlite3.Row) -> dict:
    d = dict(row)
    d["details"] = json.loads(d.get("details") or "{}")
    if "acknowledged" in d:
        d["acknowledged"] = bool(d["acknowledged"])
    if "resolved" in d:
        d["resolved"] = bool(d["resolved"])
    return d


def get_alert(alert_id: int) -> dict:
    with _lock:
        row = _get_conn().execute(
            "SELECT * FROM alerts WHERE id = ?", (alert_id,)
        ).fetchone()
    return _row_to_dict(row) if row else {}


def get_alerts(
    limit: int = 50,
    severity: str | None = None,
    since_id: int | None = None,
) -> list[dict]:
    query = "SELECT * FROM alerts"
    clauses, params = [], []
    if severity:
        clauses.append("severity = ?")
        params.append(severity)
    if since_id is not None:
        clauses.append("id > ?")
        params.append(since_id)
    if clauses:
        query += " WHERE " + " AND ".join(clauses)
    query += " ORDER BY id DESC LIMIT ?"
    params.append(limit)
    with _lock:
        rows = _get_conn().execute(query, params).fetchall()
    return [_row_to_dict(r) for r in rows]


def get_stats() -> dict:
    with _lock:
        conn = _get_conn()
        total = conn.execute("SELECT COUNT(*) FROM alerts").fetchone()[0]
        by_sev = dict(
            conn.execute(
                "SELECT severity, COUNT(*) FROM alerts GROUP BY severity"
            ).fetchall()
        )
        today = conn.execute(
            "SELECT COUNT(*) FROM alerts WHERE ts >= date('now')"
        ).fetchone()[0]
    high = by_sev.get("high", 0)
    risk = "HIGH" if high >= 3 else "MED" if high >= 1 else "LOW"
    return {
        "total_alerts": total,
        "alerts_today": today,
        "high": high,
        "medium": by_sev.get("medium", 0),
        "low": by_sev.get("low", 0),
        "risk_level": risk,
        "cameras_total": len(config.CAMERAS),
    }


def clear_alerts() -> None:
    with _lock:
        _get_conn().execute("DELETE FROM alerts")
        _get_conn().commit()


def acknowledge_alert(alert_id: int) -> dict | None:
    with _lock:
        _get_conn().execute("UPDATE alerts SET acknowledged = 1 WHERE id = ?", (alert_id,))
        _get_conn().commit()
    return get_alert(alert_id) or None


def resolve_alert(alert_id: int) -> dict | None:
    with _lock:
        _get_conn().execute("UPDATE alerts SET resolved = 1, acknowledged = 1 WHERE id = ?", (alert_id,))
        _get_conn().commit()
    return get_alert(alert_id) or None


def delete_alert(alert_id: int) -> bool:
    with _lock:
        cur = _get_conn().execute("DELETE FROM alerts WHERE id = ?", (alert_id,))
        _get_conn().commit()
        return cur.rowcount > 0


# ── emergency contacts ───────────────────────────────────────────────
def get_contacts(user_id: int) -> list[dict]:
    with _lock:
        rows = _get_conn().execute(
            "SELECT * FROM emergency_contacts WHERE user_id = ? ORDER BY id", (user_id,)
        ).fetchall()
    return [dict(r) for r in rows]


def add_contact(user_id: int, name: str, relation: str, phone: str) -> dict:
    with _lock:
        cur = _get_conn().execute(
            "INSERT INTO emergency_contacts (user_id, name, relation, phone) VALUES (?, ?, ?, ?)",
            (user_id, name, relation, phone),
        )
        _get_conn().commit()
        contact_id = cur.lastrowid
        row = _get_conn().execute("SELECT * FROM emergency_contacts WHERE id = ?", (contact_id,)).fetchone()
    return dict(row)


def delete_contact(user_id: int, contact_id: int) -> bool:
    with _lock:
        cur = _get_conn().execute(
            "DELETE FROM emergency_contacts WHERE id = ? AND user_id = ?", (contact_id, user_id)
        )
        _get_conn().commit()
        return cur.rowcount > 0


# ── preferences (stored as a JSON blob per user) ────────────────────
DEFAULT_PREFERENCES = {
    "Avoid Isolated Areas": True,
    "Prefer Crowded Routes": True,
    "Night Mode Alerts": False,
}


def get_preferences(user_id: int) -> dict:
    user = get_user_by_id(user_id)
    raw = user.get("preferences") if user else None
    if not raw:
        return dict(DEFAULT_PREFERENCES)
    try:
        return {**DEFAULT_PREFERENCES, **json.loads(raw)}
    except (json.JSONDecodeError, TypeError):
        return dict(DEFAULT_PREFERENCES)


def update_preferences(user_id: int, prefs: dict) -> dict:
    merged = {**get_preferences(user_id), **prefs}
    with _lock:
        _get_conn().execute(
            "UPDATE users SET preferences = ? WHERE id = ?", (json.dumps(merged), user_id)
        )
        _get_conn().commit()
    return merged


# ── analytics ────────────────────────────────────────────────────────
def get_analytics() -> dict:
    with _lock:
        conn = _get_conn()
        daily = conn.execute(
            """
            SELECT date(ts) AS day, COUNT(*) AS count
            FROM alerts
            WHERE ts >= date('now', '-6 days')
            GROUP BY day
            ORDER BY day
            """
        ).fetchall()
        severity = conn.execute("SELECT severity, COUNT(*) FROM alerts GROUP BY severity").fetchall()
        by_type = conn.execute(
            "SELECT type, COUNT(*) AS count FROM alerts GROUP BY type ORDER BY count DESC LIMIT 10"
        ).fetchall()
        by_camera = conn.execute(
            """
            SELECT camera_id, camera_name, COUNT(*) AS count
            FROM alerts
            GROUP BY camera_id, camera_name
            ORDER BY count DESC
            LIMIT 10
            """
        ).fetchall()
        resolved = conn.execute("SELECT COUNT(*) FROM alerts WHERE resolved = 1").fetchone()[0]
        acknowledged = conn.execute("SELECT COUNT(*) FROM alerts WHERE acknowledged = 1").fetchone()[0]
        total = conn.execute("SELECT COUNT(*) FROM alerts").fetchone()[0]

    return {
        "daily_alerts": [{"day": r["day"], "count": r["count"]} for r in daily],
        "severity_breakdown": dict(severity),
        "top_alert_types": [{"type": r["type"], "count": r["count"]} for r in by_type],
        "camera_performance": [
            {"camera_id": r["camera_id"], "camera_name": r["camera_name"], "count": r["count"]} for r in by_camera
        ],
        "total_alerts": total,
        "resolved": resolved,
        "acknowledged": acknowledged,
        "resolution_rate": round(resolved / total, 3) if total else 0.0,
    }
