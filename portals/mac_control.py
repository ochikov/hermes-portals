"""Launch/status/stop only. No network API can synthesize mouse or app actions.

The human starts camera capture/control in the native app. A private local
status file and stop request let Portals coordinate its own camera mode.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "native/macos/build/Hermes Portals Control.app"


class MacController:
    def __init__(self, *, directory: Path | None = None, app: Path = APP, platform: str | None = None):
        self.directory = directory or Path.home() / "Library/Application Support/Hermes Portals Control"
        self.app = app
        self.supported = (platform or sys.platform) == "darwin"

    def status(self) -> dict:
        result = {"supported": self.supported, "installed": self.supported and self.app.is_dir(),
                  "running": False, "capturing": False, "starting": False, "control_enabled": False, "armed": False,
                  "camera_allowed": False, "accessibility_allowed": False, "mode": "off", "click_gesture": "pinch"}
        if not self.supported:
            return result
        try:
            path = self.directory / "status.json"
            if path.stat().st_size > 4096:
                return result
            data = json.loads(path.read_text())
            stamp = data.get("updated_at")
            if type(stamp) not in (int, float) or not 0 <= time.time() - stamp < 4:
                return result
            if data.get("mode") not in ("off", "preview", "control"):
                return result
            result.update(running=True, mode=data["mode"])
            if data.get("click_gesture") in ("indexTap", "pinch"):
                result["click_gesture"] = data["click_gesture"]
            for key in ("capturing", "starting", "control_enabled", "armed", "camera_allowed", "accessibility_allowed"):
                result[key] = data.get(key) is True
        except (OSError, ValueError, TypeError, AttributeError):
            pass
        return result

    def open(self) -> dict:
        if not self.supported:
            raise ValueError("Mac control requires macOS")
        if not self.app.is_dir():
            raise ValueError("Build the native controller first: ./scripts/build_macos.sh")
        try:
            subprocess.run(["/usr/bin/open", str(self.app)], check=True, timeout=10,
                           stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        except (OSError, subprocess.SubprocessError) as error:
            raise ValueError("Could not open the Mac controller. Try opening its app in Finder.") from error
        return {**self.status(), "message": "Controller opened. Choose Preview or Start Mac control in its window."}

    def stop(self) -> dict:
        if not self.supported:
            raise ValueError("Mac control requires macOS")
        if not self.status()["running"]:
            return {**self.status(), "message": "Controller is not running."}
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        path = self.directory / "stop.request"
        # No PID signalling or executable commands; the app only recognizes stop.
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(descriptor, "w") as stream:
            stream.write("stop\n")
        return {**self.status(), "message": "Stop requested. Camera and Mac input will turn off."}
