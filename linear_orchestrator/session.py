"""Map Linear issues / agent sessions to durable hermes sessions on disk."""
from __future__ import annotations
import sqlite3
from pathlib import Path
from datetime import datetime, timezone


SCHEMA = """
CREATE TABLE IF NOT EXISTS sessions (
  session_key  TEXT PRIMARY KEY,
  hermes_id    TEXT,
  issue_id     TEXT,
  issue_iden   TEXT,
  agent_sess   TEXT,
  first_seen   TEXT,
  last_seen    TEXT,
  events_count INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS deliveries (
  delivery_id TEXT PRIMARY KEY,
  ts          TEXT,
  session_key TEXT,
  status      TEXT,
  detail      TEXT,
  latency_ms  INTEGER DEFAULT 0
);
-- back-compat add column for older sqlite files (no-op if exists)
"""


def _maybe_add_latency_column(conn: sqlite3.Connection) -> None:
    """Old databases predate latency_ms; add it as a no-op upgrade."""
    cols = {r[1] for r in conn.execute("PRAGMA table_info(deliveries)").fetchall()}
    if "latency_ms" not in cols:
        conn.execute("ALTER TABLE deliveries ADD COLUMN latency_ms INTEGER DEFAULT 0")
        conn.commit()


class SessionStore:
    def __init__(self, path: Path):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(path))
        self._conn.executescript(SCHEMA)
        _maybe_add_latency_column(self._conn)
        self._conn.commit()

    def upsert(self, session_key: str, issue_id: str = "", issue_iden: str = "",
               agent_sess: str = "") -> None:
        now = datetime.now(timezone.utc).isoformat()
        cur = self._conn.cursor()
        cur.execute(
            """INSERT INTO sessions(session_key,issue_id,issue_iden,agent_sess,first_seen,last_seen,events_count)
               VALUES(?,?,?,?,?,?,1)
               ON CONFLICT(session_key) DO UPDATE SET
                 last_seen=excluded.last_seen,
                 events_count=events_count+1""",
            (session_key, issue_id, issue_iden, agent_sess, now, now),
        )
        self._conn.commit()

    def already_processed(self, delivery_id: str) -> bool:
        cur = self._conn.cursor()
        row = cur.execute("SELECT 1 FROM deliveries WHERE delivery_id=?", (delivery_id,)).fetchone()
        return row is not None

    def record_delivery(self, delivery_id: str, session_key: str, status: str,
                        detail: str = "", latency_ms: int = 0) -> None:
        now = datetime.now(timezone.utc).isoformat()
        cur = self._conn.cursor()
        cur.execute(
            "INSERT OR REPLACE INTO deliveries(delivery_id,ts,session_key,status,detail,latency_ms) VALUES(?,?,?,?,?,?)",
            (delivery_id, now, session_key, status, detail[:2000], int(latency_ms or 0)),
        )
        self._conn.commit()

    def stats_24h(self) -> dict:
        """Aggregate stats over the last 24h for the dashboard."""
        cur = self._conn.cursor()
        rows = cur.execute(
            """SELECT status, COUNT(*) as n, COALESCE(AVG(NULLIF(latency_ms,0)),0) as avg_ms
               FROM deliveries
               WHERE ts > datetime('now','-1 day')
               GROUP BY status"""
        ).fetchall()
        total = sum(r[1] for r in rows)
        per_status = {r[0]: {"count": r[1], "avg_ms": round(r[2])} for r in rows}
        ok_states = {"written", "queued", "hermes_skip"}
        written = sum(r[1] for r in rows if r[0] in ok_states)
        ran_states = {"written", "write_fail", "hermes_fail", "hermes_skip", "exception"}
        ran = sum(r[1] for r in rows if r[0] in ran_states)
        avg_ms = round(sum(r[1] * r[2] for r in rows) / total) if total else 0
        sess_count = cur.execute(
            "SELECT COUNT(*) FROM sessions WHERE last_seen > datetime('now','-1 day')"
        ).fetchone()[0]
        return {
            "window_hours": 24,
            "total_deliveries": total,
            "active_sessions": sess_count,
            "by_status": per_status,
            "agent_runs": ran,
            "success_rate": round(written / ran, 3) if ran else None,
            "avg_processing_ms": avg_ms,
        }
