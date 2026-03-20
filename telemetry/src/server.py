"""
Fishtank Roku Telemetry Server
Minimal receiver for anonymous usage events.
"""

import json
import sqlite3
import os
from functools import wraps
from datetime import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)
DB_PATH = os.environ.get("TELEMETRY_DB", "telemetry.db")
API_INGEST_TOKEN = os.environ.get("TELEMETRY_INGEST_TOKEN", "")
API_STATS_TOKEN = os.environ.get("TELEMETRY_STATS_TOKEN", "")


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


@app.route("/api/telemetry", methods=["POST"])
@require_ingest_token
def receive_event():
    try:
        data = request.get_json(force=True)
    except Exception:
        return jsonify({"error": "invalid json"}), 400

    device_id = data.get("device_id", "unknown")
    event = data.get("event", "unknown")
    app_version = data.get("app_version", "")
    roku_model = data.get("roku_model", "")
    firmware = data.get("firmware", "")
    display_mode = data.get("display_mode", "")
    event_data = json.dumps(data.get("data")) if data.get("data") else None
    client_timestamp = data.get("timestamp", "")

    db = get_db()
    db.execute(
        """
        INSERT INTO events
            (device_id, event, app_version, roku_model, firmware,
             display_mode, event_data, client_timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (device_id, event, app_version, roku_model, firmware,
         display_mode, event_data, client_timestamp),
    )
    db.commit()
    db.close()

    print(f"[{datetime.now().isoformat()}] {event} from {device_id[:8]}...")

    return jsonify({"ok": True}), 200


@app.route("/api/stats", methods=["GET"])
@require_stats_token
def stats():
    """Quick dashboard stats - protected by token."""
    db = get_db()

    # Total events
    total = db.execute("SELECT COUNT(*) as c FROM events").fetchone()["c"]

    # Unique devices (all time)
    unique_devices = db.execute(
        "SELECT COUNT(DISTINCT device_id) as c FROM events"
    ).fetchone()["c"]

    # Unique devices (last 24h)
    active_24h = db.execute(
        "SELECT COUNT(DISTINCT device_id) as c FROM events WHERE server_timestamp > datetime('now', '-1 day')"
    ).fetchone()["c"]

    # Unique devices (last 7 days)
    active_7d = db.execute(
        "SELECT COUNT(DISTINCT device_id) as c FROM events WHERE server_timestamp > datetime('now', '-7 days')"
    ).fetchone()["c"]

    # Events by type
    event_counts = db.execute(
        "SELECT event, COUNT(*) as c FROM events GROUP BY event ORDER BY c DESC"
    ).fetchall()

    # Most popular cameras
    popular_cams = db.execute(
        """
        SELECT json_extract(event_data, '$.camera_id') as cam, COUNT(*) as c
        FROM events
        WHERE event = 'stream_play' AND event_data IS NOT NULL
        GROUP BY cam ORDER BY c DESC LIMIT 10
        """
    ).fetchall()

    # Roku models
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
