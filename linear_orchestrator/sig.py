"""Linear webhook signature + timestamp verification."""
from __future__ import annotations
import hmac
import hashlib
import json
import time
from typing import Tuple


def verify(body: bytes, secret: str, sig_header: str, ts_header: str,
           tolerance_sec: int = 60) -> Tuple[bool, str]:
    """Return (ok, reason)."""
    if not secret:
        return False, "no secret configured"
    if not sig_header:
        return False, "missing Linear-Signature"

    expected = hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(sig_header.strip().lower(), expected.lower()):
        return False, "signature mismatch"

    # timestamp: header OR webhookTimestamp field in body
    ts_value = ts_header
    if not ts_value:
        try:
            ts_value = str(json.loads(body.decode("utf-8")).get("webhookTimestamp", ""))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return False, "body not JSON; no timestamp header"

    try:
        ts_ms = int(ts_value)
    except (TypeError, ValueError):
        return False, "timestamp missing or invalid"

    ts_sec = ts_ms / 1000 if ts_ms > 10_000_000_000 else ts_ms
    if abs(time.time() - ts_sec) > tolerance_sec:
        return False, f"timestamp outside ±{tolerance_sec}s window"
    return True, "ok"
