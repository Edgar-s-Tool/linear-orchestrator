"""aiohttp server: receive Linear webhook → parse → run hermes → write back."""
from __future__ import annotations
import asyncio
import json
import logging
import time
from pathlib import Path
from aiohttp import web

from .config import Config
from .sig import verify as verify_sig
from .parser import parse as parse_event, should_act
from .session import SessionStore
from .runner import run_hermes
from .writer import write_back

log = logging.getLogger("orch.server")


async def _handle_linear(request: web.Request) -> web.Response:
    cfg: Config = request.app["cfg"]
    store: SessionStore = request.app["store"]
    body = await request.read()
    sig = request.headers.get("Linear-Signature", "")
    ts = request.headers.get("Linear-Timestamp", "")
    delivery_id = (request.headers.get("Linear-Delivery", "") or
                   request.headers.get("X-Request-ID", "") or
                   f"d-{int(time.time()*1000)}")

    ok, reason = verify_sig(body, cfg.linear_webhook_secret, sig, ts)
    if not ok:
        log.warning("sig verify failed: %s", reason)
        return web.json_response({"error": "invalid signature", "reason": reason}, status=401)

    if store.already_processed(delivery_id):
        return web.json_response({"status": "duplicate", "delivery_id": delivery_id})

    try:
        payload = json.loads(body.decode("utf-8"))
    except Exception as e:
        return web.json_response({"error": f"bad json: {e}"}, status=400)

    ev = parse_event(payload, cfg.agent_linear_user_id)
    act, why = should_act(ev)
    log.info("event type=%s action=%s issue=%s session=%s act=%s why=%s",
             ev.type, ev.action, ev.issue_identifier, ev.session_key, act, why)

    store.upsert(ev.session_key, ev.issue_id, ev.issue_identifier, ev.agent_session_id)

    if not act:
        store.record_delivery(delivery_id, ev.session_key, "skip", why)
        return web.json_response({"status": "skip", "reason": why,
                                  "session": ev.session_key,
                                  "delivery_id": delivery_id})

    # respond fast to Linear; do the heavy work in background
    request.app["_pending"].add(asyncio.create_task(
        _process(cfg, store, ev, delivery_id)
    ))
    return web.json_response({"status": "queued", "session": ev.session_key,
                              "delivery_id": delivery_id, "act_reason": why}, status=202)


async def _process(cfg: Config, store: SessionStore, ev, delivery_id: str) -> None:
    try:
        log.info("→ run hermes for delivery=%s session=%s", delivery_id, ev.session_key)
        ok, reply = await run_hermes(ev, cfg.hermes_path, cfg.hermes_timeout_sec,
                                     ev.session_key, cfg.default_model)
        if not ok:
            log.warning("hermes failed: %s", reply[:200])
            store.record_delivery(delivery_id, ev.session_key, "hermes_fail", reply[:1000])
            return
        if not reply:
            store.record_delivery(delivery_id, ev.session_key, "hermes_skip", "agent returned __SKIP__")
            return
        log.info("← hermes replied %d chars; writing back", len(reply))
        ok_w, detail = await write_back(ev, reply, cfg.linear_api_key)
        store.record_delivery(delivery_id, ev.session_key,
                              "written" if ok_w else "write_fail", detail[:1000])
    except Exception as e:
        log.exception("process error")
        store.record_delivery(delivery_id, ev.session_key, "exception", str(e)[:500])


async def _healthz(request: web.Request) -> web.Response:
    return web.json_response({"ok": True, "ts": int(time.time())})


def make_app(cfg: Config | None = None) -> web.Application:
    cfg = cfg or Config.from_env()
    db_path = Path.home() / ".local" / "share" / "linear-orchestrator" / "sessions.db"
    store = SessionStore(db_path)
    app = web.Application()
    app["cfg"] = cfg
    app["store"] = store
    app["_pending"] = set()
    app.router.add_post("/webhooks/linear", _handle_linear)
    app.router.add_get("/healthz", _healthz)
    return app


def run() -> None:
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s %(levelname)s %(name)s %(message)s")
    cfg = Config.from_env()
    app = make_app(cfg)
    log.info("linear-orchestrator listening on %s:%s", cfg.host, cfg.port)
    web.run_app(app, host=cfg.host, port=cfg.port, print=None, access_log=None)


if __name__ == "__main__":
    run()
