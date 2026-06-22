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
  detail      TEXT
);
"""


class SessionStore:
    def __init__(self, path: Path):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(path))
        self._conn.executescript(SCHEMA)
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

    def record_delivery(self, delivery_id: str, session_key: str, status: str, detail: str = "") -> None:
        now = datetime.now(timezone.utc).isoformat()
        cur = self._conn.cursor()
        cur.execute(
            "INSERT OR REPLACE INTO deliveries(delivery_id,ts,session_key,status,detail) VALUES(?,?,?,?,?)",
            (delivery_id, now, session_key, status, detail[:2000]),
        )
        self._conn.commit()
