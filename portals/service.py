"""Explicit native slash-command lifecycle. Only stdlib; no shell execution."""
from __future__ import annotations

import ipaddress
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from .store import Store

ROOT = Path(__file__).resolve().parents[1]


def running(directory: Path) -> dict | None:
    path = directory / "runtime.json"
    if not path.exists():
        return None
    try:
        info = json.loads(path.read_text())
        port = int(info["port"])
        if not 1024 <= port <= 65535:
            return None
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/api/health", timeout=1) as response:
            health = json.load(response)
        return info if health.get("instance") == info.get("instance") and health.get("service") == "hermes-portals" else None
    except (OSError, ValueError, KeyError):
        return None


def owner_url(directory: Path) -> str:
    info = running(directory)
    if not info:
        raise ValueError("Portals is not running. Use /portals start [laptop LAN IP].")
    token = Store(directory).invitation("owner")
    return f"http://127.0.0.1:{info['port']}/#owner={token}"


def start(directory: Path, lan: str | None = None, port: int = 8766) -> str:
    if lan:
        addr = ipaddress.ip_address(lan)
        if addr.version != 4 or not addr.is_private or addr.is_loopback or addr.is_unspecified:
            raise ValueError("Use this laptop's private IPv4 address")
    current = running(directory)
    if current:
        if lan and current.get("lan") != lan:
            raise ValueError("The running service uses a different network address; restart it before changing networks.")
        return owner_url(directory)
    python = ROOT / ".venv" / "bin" / "python"
    if not python.exists() or not (ROOT / "web/vendor/hand_landmarker.task").exists():
        raise ValueError("Run scripts/setup.sh inside the Portals project first.")
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    command = [str(python), "-m", "portals.server", "--data-dir", str(directory), "--port", str(port)]
    if lan:
        command += ["--lan", lan]
    # The companion needs no provider keys or unattended/approval flags.
    env = {key: os.environ[key] for key in ("PATH", "LANG", "LC_ALL", "TMPDIR") if key in os.environ}
    with (directory / "server.log").open("a") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                                   stdout=log, stderr=log, start_new_session=True)
    for _ in range(40):
        if running(directory):
            return owner_url(directory)
        if process.poll() is not None:
            raise ValueError(f"Portals did not start. See {directory / 'server.log'}")
        time.sleep(.15)
    process.terminate()
    raise ValueError("Portals startup timed out")


def stop(directory: Path) -> str:
    info = running(directory)
    if not info:
        return "Portals is already stopped."
    store = Store(directory)
    token = store.redeem(store.invitation("owner"), "owner", "Laptop")
    origin = f"http://127.0.0.1:{info['port']}"
    cookie = f"portals_{info['port']}_{info['instance'][:8]}"
    request = urllib.request.Request(origin + "/api/shutdown", data=b"{}", headers={
        "Origin": origin, "Content-Type": "application/json", "Cookie": cookie + "=" + token,
    })
    with urllib.request.urlopen(request, timeout=2) as response:
        json.load(response)
    return "Portals is stopping. Your tool library and state are saved."


def command(directory: Path, raw: str) -> str:
    parts = raw.strip().split()
    verb = parts[0] if parts else "status"
    try:
        if verb == "mac" and len(parts) == 2:
            from .mac_control import MacController
            controller = MacController()
            if parts[1] == "status":
                return json.dumps(controller.status())
            if parts[1] == "open":
                return json.dumps(controller.open())
            if parts[1] == "stop":
                return json.dumps(controller.stop())
            return "Usage: /portals mac open | status | stop"
        if verb == "start" and len(parts) <= 2:
            url = start(directory, parts[1] if len(parts) == 2 else None)
            return f"Open this one-use laptop invitation within 2 minutes:\n{url}\nEnable the webcam on the page, then pair your phone."
        if verb == "open" and len(parts) == 1:
            return "Open this one-use laptop invitation within 2 minutes:\n" + owner_url(directory)
        if verb == "status":
            info = running(directory)
            return json.dumps({"running": bool(info), "network": info,
                               **Store(directory).workspace(), "phone": Store(directory).phone()})
        if verb == "revoke" and len(parts) == 1:
            Store(directory).revoke_phone()
            return "Phone access revoked. The active tool is back on the laptop."
        if verb == "stop" and len(parts) == 1:
            return stop(directory)
        return "Usage: /portals start [laptop-LAN-IP] | open | status | revoke | stop | mac open/status/stop"
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        return "Portals: " + str(error)
