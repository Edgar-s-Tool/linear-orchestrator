"""Write agent reply back to Linear (comment or agent session activity)."""
from __future__ import annotations
import logging
import aiohttp
from .parser import Event

log = logging.getLogger("orch.writer")
LINEAR_GQL = "https://api.linear.app/graphql"


async def _gql(session: aiohttp.ClientSession, api_key: str, query: str, variables: dict) -> dict:
    async with session.post(
        LINEAR_GQL,
        json={"query": query, "variables": variables},
        headers={"Authorization": api_key, "Content-Type": "application/json"},
        timeout=aiohttp.ClientTimeout(total=30),
    ) as r:
        text = await r.text()
        if r.status >= 400:
            log.warning("linear gql %d: %s", r.status, text[:300])
            return {"error": text[:300]}
        try:
            return await r.json(content_type=None) if not text else __import__("json").loads(text)
        except Exception:
            return {"raw": text[:300]}


COMMENT_MUTATION = """
mutation CommentCreate($issueId: String!, $body: String!) {
  commentCreate(input: { issueId: $issueId, body: $body }) {
    success
    comment { id url }
  }
}
"""


AGENT_ACTIVITY_MUTATION = """
mutation AgentSessionActivity($agentSessionId: String!, $type: AgentSessionActivityType!, $body: String!) {
  agentSessionActivityCreate(input: {
    agentSessionId: $agentSessionId,
    type: $type,
    body: $body
  }) {
    success
    activity { id }
  }
}
"""


def _dig(d, *keys, default=None):
    """Null-safe nested get — treats both missing keys AND None values as 'not present'."""
    cur = d
    for k in keys:
        if not isinstance(cur, dict):
            return default
        cur = cur.get(k)
        if cur is None:
            return default
    return cur if cur is not None else default


async def write_back(ev: Event, reply: str, api_key: str) -> tuple[bool, str]:
    """Returns (ok, detail)."""
    if not reply.strip():
        return True, "no reply (skip)"

    async with aiohttp.ClientSession() as session:
        if ev.agent_session_id:
            data = await _gql(session, api_key, AGENT_ACTIVITY_MUTATION, {
                "agentSessionId": ev.agent_session_id,
                "type": "text",
                "body": reply,
            })
            ok = bool(_dig(data, "data", "agentSessionActivityCreate", "success", default=False))
            errors = data.get("errors") if isinstance(data, dict) else None
            return ok, f"agentActivity ok={ok} errors={str(errors)[:200] if errors else 'none'}"

        if not ev.issue_id:
            return False, "no issue_id and no agent_session_id; nowhere to write"

        data = await _gql(session, api_key, COMMENT_MUTATION, {
            "issueId": ev.issue_id,
            "body": reply,
        })
        ok = bool(_dig(data, "data", "commentCreate", "success", default=False))
        url = _dig(data, "data", "commentCreate", "comment", "url", default="")
        errors = data.get("errors") if isinstance(data, dict) else None
        detail = f"comment ok={ok} url={url}"
        if errors:
            detail += f" errors={str(errors)[:250]}"
        return ok, detail
