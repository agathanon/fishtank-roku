"""
Fishtank Roku Telemetry Server
Minimal receiver for anonymous usage events.
"""

import json
import sqlite3
import os
import time
from functools import wraps
from datetime import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)

# Max request body size (4KB — a normal event is ~500 bytes)
app.config["MAX_CONTENT_LENGTH"] = 4096

DB_PATH = os.environ.get("TELEMETRY_DB", "telemetry.db")
API_INGEST_TOKEN = os.environ.get("TELEMETRY_INGEST_TOKEN", "")
API_STATS_TOKEN = os.environ.get("TELEMETRY_STATS_TOKEN", "")

# ============================================================
#  Validation constants
# ============================================================

ALLOWED_EVENTS = {
    "app_open",
    "session_restored",
    "login_success",
    "stream_play",
    "stream_error",
    "panel_open",
    "panel_close",
    "logout",
    "app_exit",
}

ALLOWED_FIELDS = {
    "device_id", "event", "app_version", "roku_model",
    "firmware", "display_mode", "data", "timestamp",
}

MAX_STRING_LEN = 256
MAX_EVENT_DATA_LEN = 512

# In-memory rate limiter: max events per device per window
RATE_LIMIT_WINDOW = 60      # seconds
RATE_LIMIT_MAX = 30         # max events per device per window
rate_limit_store = {}       # { device_id: [timestamp, ...] }


# ============================================================
#  Auth decorators
# ============================================================

def require_ingest_token(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not API_INGEST_TOKEN:
            return jsonify({"error": "server misconfigured: no ingest token set"}), 500

        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer ") or auth[7:] != API_INGEST_TOKEN:
            return jsonify({"error": "unauthorized"}), 401

        return f(*args, **kwargs)
    return decorated


def require_stats_token(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not API_STATS_TOKEN:
            return jsonify({"error": "server misconfigured: no stats token set"}), 500

        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer ") or auth[7:] != API_STATS_TOKEN:
            return jsonify({"error": "unauthorized"}), 401

        return f(*args, **kwargs)
    return decorated


# ============================================================
#  Validation helpers
# ============================================================

def is_rate_limited(device_id):
    """Returns True if this device has exceeded the rate limit."""
    now = time.time()
    cutoff = now - RATE_LIMIT_WINDOW

    if device_id not in rate_limit_store:
        rate_limit_store[device_id] = []

    # Prune old entries
    rate_limit_store[device_id] = [
        t for t in rate_limit_store[device_id] if t > cutoff
    ]

    if len(rate_limit_store[device_id]) >= RATE_LIMIT_MAX:
        return True

    rate_limit_store[device_id].append(now)
    return False


def sanitize_string(value, max_len=MAX_STRING_LEN):
    """Ensure value is a string and truncate to max length."""
    if not isinstance(value, str):
        return ""
    return value[:max_len]


def validate_payload(data):
    """Validate and sanitize the incoming payload. Returns (cleaned_data, error)."""
    if not isinstance(data, dict):
        return None, "payload must be a JSON object"

    # Reject unknown fields
    unknown = set(data.keys()) - ALLOWED_FIELDS
    if unknown:
        return None, f"unknown fields: {', '.join(unknown)}"

    # Require device_id and event
    if "device_id" not in data or not data["device_id"]:
        return None, "missing device_id"
    if "event" not in data or not data["event"]:
        return None, "missing event"

    # Validate event name
    event = data["event"]
    if event not in ALLOWED_EVENTS:
        return None, f"unknown event: {event}"

    # Sanitize all string fields
    cleaned = {
        "device_id": sanitize_string(data.get("device_id", ""), 64),
        "event": event,
        "app_version": sanitize_string(data.get("app_version", ""), 32),
        "roku_model": sanitize_string(data.get("roku_model", ""), 128),
        "firmware": sanitize_string(data.get("firmware", ""), 32),
        "display_mode": sanitize_string(data.get("display_mode", ""), 32),
        "client_timestamp": sanitize_string(data.get("timestamp", ""), 64),
        "event_data": None,
    }

    # Validate and sanitize event data
    if "data" in data and data["data"] is not None:
        if not isinstance(data["data"], dict):
            return None, "data must be a JSON object"
        raw = json.dumps(data["data"])
        if len(raw) > MAX_EVENT_DATA_LEN:
            return None, "data too large"
        cleaned["event_data"] = raw

    return cleaned, None


# ============================================================
#  Database
# ============================================================

def get_db():
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    return db


def init_db():
    db = get_db()
    db.execute("""
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            event TEXT NOT NULL,
            app_version TEXT,
            roku_model TEXT,
            firmware TEXT,
            display_mode TEXT,
            event_data TEXT,
            client_timestamp TEXT,
            server_timestamp TEXT DEFAULT (datetime('now'))
        )
    """)
    db.execute("""
        CREATE INDEX IF NOT EXISTS idx_events_event ON events(event)
    """)
    db.execute("""
        CREATE INDEX IF NOT EXISTS idx_events_device ON events(device_id)
    """)
    db.execute("""
        CREATE INDEX IF NOT EXISTS idx_events_time ON events(server_timestamp)
    """)
    db.commit()
    db.close()


# ============================================================
#  Routes
# ============================================================

@app.route("/api/telemetry", methods=["POST"])
@require_ingest_token
def receive_event():
    try:
        data = request.get_json(force=True)
    except Exception:
        return jsonify({"error": "invalid json"}), 400

    # Validate and sanitize
    cleaned, error = validate_payload(data)
    if error:
        return jsonify({"error": error}), 400

    # Rate limit
    if is_rate_limited(cleaned["device_id"]):
        return jsonify({"error": "rate limited"}), 429

    db = get_db()
    db.execute(
        """
        INSERT INTO events
            (device_id, event, app_version, roku_model, firmware,
             display_mode, event_data, client_timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (cleaned["device_id"], cleaned["event"], cleaned["app_version"],
         cleaned["roku_model"], cleaned["firmware"], cleaned["display_mode"],
         cleaned["event_data"], cleaned["client_timestamp"]),
    )
    db.commit()
    db.close()

    print(f"[{datetime.now().isoformat()}] {cleaned['event']} from {cleaned['device_id'][:8]}...")

    return jsonify({"ok": True}), 200


@app.route("/api/stats", methods=["GET"])
@require_stats_token
def stats():
    """Quick dashboard stats - protected by token."""
    db = get_db()

    total = db.execute("SELECT COUNT(*) as c FROM events").fetchone()["c"]

    unique_devices = db.execute(
        "SELECT COUNT(DISTINCT device_id) as c FROM events"
    ).fetchone()["c"]

    active_24h = db.execute(
        "SELECT COUNT(DISTINCT device_id) as c FROM events WHERE server_timestamp > datetime('now', '-1 day')"
    ).fetchone()["c"]

    active_7d = db.execute(
        "SELECT COUNT(DISTINCT device_id) as c FROM events WHERE server_timestamp > datetime('now', '-7 days')"
    ).fetchone()["c"]

    event_counts = db.execute(
        "SELECT event, COUNT(*) as c FROM events GROUP BY event ORDER BY c DESC"
    ).fetchall()

    popular_cams = db.execute(
        """
        SELECT json_extract(event_data, '$.camera_id') as cam, COUNT(*) as c
        FROM events
        WHERE event = 'stream_play' AND event_data IS NOT NULL
        GROUP BY cam ORDER BY c DESC LIMIT 10
        """
    ).fetchall()

    models = db.execute(
        "SELECT roku_model, COUNT(DISTINCT device_id) as c FROM events WHERE roku_model != '' GROUP BY roku_model ORDER BY c DESC"
    ).fetchall()

    db.close()

    return jsonify({
        "total_events": total,
        "unique_devices_all_time": unique_devices,
        "unique_devices_24h": active_24h,
        "unique_devices_7d": active_7d,
        "events_by_type": {row["event"]: row["c"] for row in event_counts},
        "popular_cameras": {row["cam"]: row["c"] for row in popular_cams},
        "roku_models": {row["roku_model"]: row["c"] for row in models},
    })


@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


init_db()

if __name__ == "__main__":
    print("Telemetry server running on :8080")
    print(f"Database: {DB_PATH}")
    print("Endpoints:")
    print("  POST /api/telemetry  — receive events (ingest token)")
    print("  GET  /api/stats      — dashboard stats (stats token)")
    print("  GET  /api/health     — health check (no auth)")
    app.run(host="0.0.0.0", port=8080)
