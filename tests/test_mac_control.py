import json
import subprocess
import time

import pytest
from fastapi.testclient import TestClient

from portals.mac_control import MacController
from portals.service import command
from test_portals import ORIGIN, room


def test_mac_routes_require_owner_and_loopback(room):
    app, owner, phone = room
    calls = []
    class FakeController:
        def status(self):
            calls.append("status")
            return {"supported": True, "running": False}
        def open(self):
            calls.append("open")
            return {"message": "Opened UI only"}
        def stop(self):
            calls.append("stop")
            return {"message": "Stopped"}
    app.state.mac_control = FakeController()
    anon = TestClient(app, base_url=ORIGIN, headers={"origin": ORIGIN})
    assert anon.get("/api/mac/status").status_code == 401
    assert phone.get("/api/mac/status").status_code == 403
    for endpoint in ("open", "stop"):
        assert phone.post("/api/mac/" + endpoint, json={}).status_code == 403
    assert calls == []
    assert owner.get("/api/mac/status", headers={"host": "192.168.50.10:8766"}).status_code == 403
    with TestClient(app, base_url=ORIGIN, headers={"origin": ORIGIN}, client=("192.168.50.20", 5000)) as remote:
        remote.cookies.update(owner.cookies)
        assert remote.get("/api/mac/status").status_code == 403
        assert remote.post("/api/mac/open", json={}).status_code == 403
    assert owner.post("/api/mac/open", json={}, headers={"origin": "https://evil.invalid"}).status_code == 403
    assert calls == []
    assert owner.get("/api/mac/status").status_code == 200
    assert owner.post("/api/mac/open", json={}).status_code == 200
    assert owner.post("/api/mac/stop", json={}).status_code == 200
    assert calls == ["status", "open", "stop"]
    assert owner.post("/api/mac/click", json={"x": 20, "y": 30}).status_code == 404


def test_status_only_accepts_fresh_bounded_known_fields(tmp_path):
    app = tmp_path / "Controller.app"
    app.mkdir()
    bridge = MacController(directory=tmp_path, app=app, platform="darwin")
    assert bridge.status()["installed"] and not bridge.status()["running"]
    state = {"updated_at": time.time(), "mode": "preview", "capturing": True,
             "control_enabled": False, "armed": False, "camera_allowed": True,
             "accessibility_allowed": False, "unrelated_private_value": "do not return"}
    path = tmp_path / "status.json"
    path.write_text(json.dumps(state))
    assert bridge.status()["capturing"] and bridge.status()["mode"] == "preview"
    assert "unrelated_private_value" not in bridge.status()
    for gesture in ("indexTap", "pinch"):
        path.write_text(json.dumps({**state, "click_gesture": gesture}))
        assert bridge.status()["click_gesture"] == gesture
    path.write_text(json.dumps({**state, "click_gesture": "unrelated private text"}))
    assert bridge.status()["click_gesture"] == "pinch"
    for value in ({**state, "updated_at": time.time() - 10}, {**state, "updated_at": time.time() + 20},
                  {**state, "updated_at": "now"}, {**state, "mode": "shell"}, []):
        path.write_text(json.dumps(value))
        assert not bridge.status()["running"]
    path.write_text(" " * 5000)
    assert not bridge.status()["running"]


def test_launch_has_no_control_arguments_and_stop_only_writes_request(tmp_path, monkeypatch):
    app = tmp_path / "Controller.app"
    app.mkdir()
    bridge = MacController(directory=tmp_path, app=app, platform="darwin")
    calls = []
    monkeypatch.setattr(subprocess, "run", lambda args, **kwargs: calls.append((args, kwargs)))
    bridge.open()
    assert calls[0][0] == ["/usr/bin/open", str(app)]
    assert not calls[0][1].get("shell")
    assert not (tmp_path / "stop.request").exists()
    bridge.stop()
    assert not (tmp_path / "stop.request").exists()
    (tmp_path / "status.json").write_text(json.dumps({"updated_at": time.time(), "mode": "control", "capturing": True}))
    bridge.stop()
    assert (tmp_path / "stop.request").read_text() == "stop\n"
    assert (tmp_path / "stop.request").stat().st_mode & 0o777 == 0o600
    assert len(calls) == 1


def test_unsupported_or_missing_controller_never_launches(tmp_path, monkeypatch):
    def unexpected(*args, **kwargs):
        raise AssertionError("Should not launch a process")
    monkeypatch.setattr(subprocess, "run", unexpected)
    bridge = MacController(directory=tmp_path, platform="linux")
    assert not bridge.status()["supported"]
    with pytest.raises(ValueError):
        bridge.open()
    with pytest.raises(ValueError):
        bridge.stop()
    with pytest.raises(ValueError):
        MacController(directory=tmp_path, app=tmp_path / "missing.app", platform="darwin").open()


def test_mac_slash_commands_only_open_status_or_stop(tmp_path, monkeypatch):
    monkeypatch.setattr(MacController, "status", lambda self: {"supported": True, "running": False})
    assert json.loads(command(tmp_path, "mac status"))["running"] is False
    assert "Usage" in command(tmp_path, "mac click")
    assert "Usage" in command(tmp_path, "mac open extra")
