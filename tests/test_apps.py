import importlib.util
import json
import sqlite3
from pathlib import Path

import pytest

from portals.artifacts import MAX_ARTIFACTS, template, validate_artifact
from portals.store import AccessDenied, Store, demo, validate_graph
from test_portals import act, room


def test_library_survives_switch_handoff_phone_edit_and_restart(room, tmp_path):
    app, owner, phone = room
    diagram = act(owner, type="set_node", node="a", enabled=False).json()["artifact"]
    checklist = act(owner, type="template", template="checklist").json()["artifact"]
    assert checklist["kind"] == "checklist" and "nodes" not in checklist
    act(owner, type="handoff", target="phone")
    edited = act(phone, type="set_item", item="scope", done=True).json()["artifact"]
    assert edited["id"] == checklist["id"] and edited["items"][0]["done"]
    act(phone, type="handoff", target="laptop")
    calculator = act(owner, type="template", template="calculator").json()["artifact"]
    act(owner, type="set_value", field="days", value=42)
    act(owner, type="handoff", target="phone")
    assert phone.get("/api/state").json()["artifact"]["fields"][1]["value"] == 42
    act(phone, type="set_value", field="people", value=5)
    act(phone, type="handoff", target="laptop")
    reopened = act(owner, type="open", artifact_id=diagram["id"]).json()["artifact"]
    assert reopened["disabled"] == ["a"] and reopened["revision"] > calculator["revision"]
    reopened = act(owner, type="open", artifact_id=checklist["id"]).json()["artifact"]
    assert reopened["items"][0]["done"]
    app.state.store.reset_access()
    store = Store(tmp_path)
    assert len(store.workspace()["library"]) == 3
    restored = store.mutate({"type": "open", "artifact_id": calculator["id"]}, store.snapshot()["revision"])
    assert restored["fields"][0]["value"] == 5
    assert restored["fields"][1]["value"] == 42
    assert restored["display"] == "laptop"


def test_legacy_diagram_migration_preserves_identity_and_edits(tmp_path):
    legacy = demo()
    legacy.pop("kind")
    legacy.pop("schema_version")
    legacy.update(disabled=["a"], selected="b", revision=42)
    with sqlite3.connect(tmp_path / "portals.sqlite3") as db:
        db.execute("CREATE TABLE artifact(id INTEGER PRIMARY KEY, body TEXT NOT NULL)")
        db.execute("INSERT INTO artifact VALUES(1,?)", (json.dumps(legacy),))
    store = Store(tmp_path)
    assert store.snapshot() == {**legacy, "kind": "diagram", "schema_version": 1}
    assert store.workspace()["library"] == [{"id": legacy["id"], "title": legacy["title"], "kind": "diagram"}]
    assert Store(tmp_path).workspace() == store.workspace()


def test_phone_cannot_create_or_switch_and_types_are_enforced(room):
    app, owner, phone = room
    ident = app.state.store.snapshot()["id"]
    for action in ({"type": "template", "template": "checklist"},
                   {"type": "create", "artifact": template("calculator")},
                   {"type": "open", "artifact_id": ident}):
        assert act(phone, **action).status_code == 403
    assert phone.get("/api/state").status_code == 200
    assert act(owner, type="set_item", item="scope", done=True).status_code == 400
    act(owner, type="template", template="checklist")
    assert act(owner, type="set_node", node="a", enabled=False).status_code == 400
    assert act(owner, type="restore").status_code == 400
    assert act(phone, type="set_item", item="scope", done="true").status_code == 422
    assert act(phone, type="set_item", item="missing", done=True).status_code == 400


def test_stale_update_cannot_change_a_newly_opened_tool(room):
    app, owner, phone = room
    first = act(owner, type="template", template="checklist").json()["artifact"]
    second = act(owner, type="template", template="checklist").json()["artifact"]
    response = phone.post("/api/action", json={"type": "set_item", "item": "scope", "done": True, "revision": first["revision"]})
    assert response.status_code == 409
    assert response.json()["artifact"]["id"] == second["id"]
    assert not response.json()["artifact"]["items"][0]["done"]
    assert len(response.json()["library"]) == 3


def test_calculator_rejects_bad_data_without_mutating(room):
    app, owner, phone = room
    created = act(owner, type="template", template="calculator").json()["artifact"]
    for value in (-1, 91, True, "50"):
        assert act(phone, type="set_value", field="days", value=value).status_code in (400, 422)
        assert app.state.store.snapshot() == created
    assert act(phone, type="set_value", field="missing", value=3).status_code == 400
    assert act(phone, type="set_values", values={"days": 40, "people": 99}).status_code == 400
    assert app.state.store.snapshot() == created
    saved = act(owner, type="set_values", values={"days": 40, "people": 5}).json()["artifact"]
    assert saved["revision"] == created["revision"] + 1
    assert [field["value"] for field in saved["fields"]][:2] == [5, 40]
    for field, value in (("value", float("nan")), ("min", float("-inf")), ("max", 0), ("step", -1), ("value", 10**9)):
        definition = template("calculator")
        definition["fields"][0][field] = value
        with pytest.raises(ValueError):
            validate_artifact(definition)
    definition = template("calculator")
    definition["outputs"][0]["operation"] = "eval"
    with pytest.raises(ValueError):
        validate_artifact(definition)
    definition = template("calculator")
    definition["outputs"][0]["fields"] = ["unknown"]
    with pytest.raises(ValueError):
        validate_artifact(definition)


def test_new_tool_push_and_reconnect_contains_library(room):
    app, owner, phone = room
    with phone.websocket_connect("ws://127.0.0.1:8766/ws", headers={"origin": "http://127.0.0.1:8766"}) as ws:
        ws.receive_json()
        created = act(owner, type="template", template="checklist").json()["artifact"]
        while True:
            update = ws.receive_json()
            if update["artifact"]["id"] == created["id"]:
                break
        assert len(update["library"]) == 2
        act(phone, type="set_item", item="scope", done=True)
    with phone.websocket_connect("ws://127.0.0.1:8766/ws", headers={"origin": "http://127.0.0.1:8766"}) as ws:
        reconnected = ws.receive_json()
        assert reconnected["artifact"]["items"][0]["done"]
        assert len(reconnected["library"]) == 2


def test_limits_duplicates_and_data_only_payloads(tmp_path):
    store = Store(tmp_path)
    value = template("checklist")
    value["items"][1]["id"] = value["items"][0]["id"]
    with pytest.raises(ValueError):
        validate_artifact(value)
    for value in (None, [], {"kind": "html", "title": "x"}, {"kind": "checklist", "title": "x", "items": [None]}):
        with pytest.raises(ValueError):
            validate_artifact(value)
    malicious = {**template("checklist"), "script": "fetch('/secrets')", "html": "<iframe>"}
    result = validate_artifact(malicious)
    assert "script" not in result and "html" not in result
    graph = demo()
    graph["source"] = ["client"]
    with pytest.raises(ValueError):
        validate_graph(graph)
    with pytest.raises(AccessDenied):
        store.mutate({"type": "template", "template": "checklist"}, owner=False)
    for _ in range(MAX_ARTIFACTS - 1):
        store.mutate({"type": "template", "template": "checklist"})
    before = store.workspace()
    with pytest.raises(ValueError):
        store.mutate({"type": "template", "template": "calculator"})
    assert store.workspace() == before


def test_native_tools_use_same_workspace_and_require_revision(tmp_path, monkeypatch):
    root = Path(__file__).resolve().parents[1]
    spec = importlib.util.spec_from_file_location("portals_test_plugin", root / "__init__.py", submodule_search_locations=[str(root)])
    module = importlib.util.module_from_spec(spec)
    import sys
    monkeypatch.setitem(sys.modules, spec.name, module)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, "data_dir", lambda: tmp_path)
    status = json.loads(module.app_tool({"action": "status"}))
    assert "error" in json.loads(module.app_tool({"action": "template", "template": "checklist"}))
    created = json.loads(module.app_tool({"action": "create", "artifact": template("calculator"), "revision": status["artifact"]["revision"]}))
    assert created["artifact"]["kind"] == "calculator" and len(created["library"]) == 2
    edited = json.loads(module.app_tool({"action": "set_value", "field": "days", "value": 60, "revision": created["artifact"]["revision"]}))
    assert Store(tmp_path).snapshot()["fields"][1]["value"] == 60
    assert "error" in json.loads(module.diagram_tool({"action": "restore", "revision": edited["artifact"]["revision"]}))
    diagram = json.loads(module.diagram_tool({"action": "show", "diagram": demo(), "revision": edited["artifact"]["revision"]}))
    assert diagram["artifact"]["kind"] == "diagram"
