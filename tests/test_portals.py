import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from portals.server import create_app
from portals.store import AccessDenied, Conflict, Store, demo, digest, validate_graph

ORIGIN = "http://127.0.0.1:8766"


@pytest.fixture
def room(tmp_path):
    app = create_app(tmp_path, lan="192.168.50.10")
    with TestClient(app, base_url=ORIGIN, headers={"origin": ORIGIN}) as owner:
        token = app.state.store.invitation("owner")
        assert owner.post("/api/exchange", json={"kind": "owner", "token": token}).status_code == 200
        with TestClient(app, base_url=ORIGIN, headers={"origin": ORIGIN}) as phone:
            pair = owner.post("/api/pair", json={}).json()
            token = pair["url"].split("#pair=")[1]
            assert phone.post("/api/exchange", json={"kind": "phone", "token": token, "name": "Test phone"}).status_code == 200
            yield app, owner, phone


def act(client, **action):
    revision = client.get("/api/state").json()["artifact"]["revision"]
    return client.post("/api/action", json={"revision": revision, **action})


def test_pair_handoff_mutate_return_and_persistence(room, tmp_path):
    app, owner, phone = room
    before = owner.get("/api/state").json()["artifact"]
    assert act(owner, type="set_node", node="a", enabled=False).status_code == 200
    assert act(owner, type="select", node="b").status_code == 200
    transferred = act(owner, type="handoff", target="phone").json()["artifact"]
    assert transferred["id"] == before["id"]
    assert transferred["disabled"] == ["a"]
    assert transferred["selected"] == "b"
    assert transferred == phone.get("/api/state").json()["artifact"]
    assert act(phone, type="set_node", node="b", enabled=False).status_code == 200
    returned = act(phone, type="handoff", target="laptop").json()["artifact"]
    assert returned["disabled"] == ["a", "b"]
    assert returned["selected"] == "b"
    assert Store(tmp_path).snapshot() == returned


def test_qr_one_use_expiry_and_rotation(room):
    app, owner, phone = room
    invitation = owner.post("/api/pair", json={}).json()
    token = invitation["url"].split("#pair=")[1]
    assert invitation["qr"].startswith("data:image/svg+xml;base64,")
    assert phone.post("/api/exchange", json={"kind": "phone", "token": token}).status_code == 200
    assert phone.post("/api/exchange", json={"kind": "phone", "token": token}).status_code == 401
    expired = app.state.store.invitation("phone")
    with app.state.store.connection() as db:
        db.execute("UPDATE tokens SET expires=0 WHERE hash=?", (digest(expired),))
    with pytest.raises(AccessDenied):
        app.state.store.redeem(expired, "phone", "x")
    older = app.state.store.invitation("phone")
    app.state.store.invitation("phone")
    with pytest.raises(AccessDenied):
        app.state.store.redeem(older, "phone", "x")


def test_authorization_origin_host_and_body_limits(room):
    app, owner, phone = room
    anonymous = TestClient(app, base_url=ORIGIN, headers={"origin": ORIGIN})
    assert anonymous.get("/api/state").status_code == 401
    assert phone.post("/api/pair", json={}).status_code == 403
    assert phone.post("/api/revoke", json={}).status_code == 403
    assert owner.post("/api/pair", json={}, headers={"origin": "https://evil.invalid"}).status_code == 403
    assert owner.get("/api/state", headers={"host": "evil.invalid"}).status_code == 400
    assert owner.post("/api/action", content=b" " * 17000, headers={"content-type": "application/json"}).status_code == 413
    assert act(phone, type="show", diagram=demo()).status_code == 422
    assert owner.get("/static/../portals/store.py").status_code == 404


def test_compare_and_swap_conflict_never_loses_other_edit(room):
    app, owner, phone = room
    revision = app.state.store.snapshot()["revision"]
    first = owner.post("/api/action", json={"revision": revision, "type": "set_node", "node": "a", "enabled": False})
    second = phone.post("/api/action", json={"revision": revision, "type": "set_node", "node": "b", "enabled": False})
    assert first.status_code == 200
    assert second.status_code == 409
    assert second.json()["artifact"]["disabled"] == ["a"]


def test_simultaneous_writers_only_one_commits(tmp_path):
    store = Store(tmp_path)
    revision = store.snapshot()["revision"]
    def update(node):
        try:
            store.mutate({"type": "set_node", "node": node, "enabled": False}, revision)
            return "saved"
        except Conflict:
            return "conflict"
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(update, ["a", "b"])) == ["conflict", "saved"]
    assert len(store.snapshot()["disabled"]) == 1


def test_live_push_reconnect_revocation(room):
    app, owner, phone = room
    with phone.websocket_connect("ws://127.0.0.1:8766/ws", headers={"origin": ORIGIN}) as ws:
        original = ws.receive_json()
        act(owner, type="set_node", node="a", enabled=False)
        for _ in range(5):
            update = ws.receive_json()
            if update["artifact"]["revision"] > original["artifact"]["revision"]:
                break
        assert update["artifact"]["disabled"] == ["a"]
    with phone.websocket_connect("ws://127.0.0.1:8766/ws", headers={"origin": ORIGIN}) as ws:
        assert ws.receive_json()["artifact"]["disabled"] == ["a"]
        assert owner.post("/api/revoke", json={}).status_code == 200
        with pytest.raises(WebSocketDisconnect) as error:
            while True:
                ws.receive_json()
        assert error.value.code == 4401
    assert phone.get("/api/state").status_code == 401
    assert app.state.store.snapshot()["display"] == "laptop"


def test_offline_phone_does_not_accept_handoff(room):
    app, owner, phone = room
    with app.state.store.connection() as db:
        db.execute("UPDATE sessions SET seen=0 WHERE role='phone'")
    assert act(owner, type="handoff", target="phone").status_code == 400


def test_restarted_server_preserves_content_but_requires_pairing(room):
    app, owner, phone = room
    act(owner, type="set_node", node="a", enabled=False)
    app.state.store.reset_access()
    assert app.state.store.snapshot()["disabled"] == ["a"]
    assert owner.get("/api/state").status_code == 401
    assert phone.get("/api/state").status_code == 401


def test_graph_validation_and_isolated_profile_storage(tmp_path):
    value = demo()
    assert validate_graph(value)["title"] == value["title"]
    value["nodes"][0]["x"] = float("nan")
    with pytest.raises(ValueError):
        validate_graph(value)
    first, second = Store(tmp_path / "first"), Store(tmp_path / "second")
    first.mutate({"type": "set_node", "node": "a", "enabled": False})
    assert second.snapshot()["disabled"] == []
    token = first.invitation("phone")
    with pytest.raises(AccessDenied):
        second.redeem(token, "phone", "Cross profile")
