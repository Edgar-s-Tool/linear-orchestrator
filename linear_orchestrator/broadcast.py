"""In-memory pub/sub for session events. NDJSON streamed to subscribers."""
from __future__ import annotations
import asyncio
import json
import time
from collections import defaultdict
from dataclasses import dataclass, field


@dataclass
class _Sub:
    queue: asyncio.Queue = field(default_factory=lambda: asyncio.Queue(maxsize=200))


class Broadcaster:
    def __init__(self) -> None:
        self._subs: dict[str, set[_Sub]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def publish(self, session_key: str, event: dict) -> None:
        async with self._lock:
            subs = list(self._subs.get(session_key, ()))
            subs += list(self._subs.get("*", ()))
        payload = {"session_key": session_key, "ts": time.time(), **event}
        for s in subs:
            try:
                s.queue.put_nowait(payload)
            except asyncio.QueueFull:
                pass

    async def subscribe(self, session_key: str) -> _Sub:
        sub = _Sub()
        async with self._lock:
            self._subs[session_key].add(sub)
        return sub

    async def unsubscribe(self, session_key: str, sub: _Sub) -> None:
        async with self._lock:
            self._subs[session_key].discard(sub)

    async def stream(self, session_key: str, response):
        """Yield NDJSON events to an aiohttp StreamResponse."""
        sub = await self.subscribe(session_key)
        # send hello so client knows it's connected before any event lands
        await response.write((json.dumps({"type": "subscribed", "session_key": session_key,
                                         "ts": time.time()}) + "\n").encode())
        try:
            while True:
                try:
                    ev = await asyncio.wait_for(sub.queue.get(), timeout=25.0)
                    await response.write((json.dumps(ev, ensure_ascii=False) + "\n").encode())
                except asyncio.TimeoutError:
                    # keepalive — empty newline keeps proxies happy
                    await response.write(b"\n")
        except (asyncio.CancelledError, ConnectionResetError):
            return
        finally:
            await self.unsubscribe(session_key, sub)
