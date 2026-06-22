from linear_orchestrator.parser import parse, should_act


def test_comment_with_mention():
    ev = parse({
        "type": "Comment",
        "action": "create",
        "data": {
            "id": "c1", "body": "@hermes 幫我看看",
            "issueId": "i1",
            "issue": {"id": "i1", "identifier": "WHO-1", "title": "t"},
        },
        "webhookTimestamp": 0,
    })
    assert ev.type == "Comment"
    assert ev.mentions_agent is True
    assert ev.session_key == "linear-issue-WHO-1"
    ok, _ = should_act(ev)
    assert ok


def test_comment_no_mention_skipped():
    ev = parse({"type": "Comment", "action": "create",
                "data": {"id": "c", "body": "plain", "issueId": "i"}})
    ok, _ = should_act(ev)
    assert ok is False


def test_agent_session_event():
    ev = parse({"type": "AgentSessionEvent",
                "data": {"agentSession": {"id": "as-9",
                                          "issue": {"id": "i", "identifier": "X-1"}},
                         "prompt": "do it"}})
    assert ev.agent_session_id == "as-9"
    assert ev.session_key == "linear-as-as-9"
    ok, _ = should_act(ev)
    assert ok
