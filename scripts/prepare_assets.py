"""Copy pinned MediaPipe runtime locally; download a versioned model once.

This is an explicit developer/setup step, never an in-app self-updater.
The browser subsequently loads all code/model bytes from this companion.
"""
import hashlib
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "node_modules/@mediapipe/tasks-vision"
DEST = ROOT / "web/vendor"
MODEL_URL = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"


def main():
    if not (PACKAGE / "vision_bundle.mjs").exists():
        raise SystemExit("Run npm ci --ignore-scripts first")
    DEST.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PACKAGE / "vision_bundle.mjs", DEST / "vision_bundle.mjs")
    shutil.copytree(PACKAGE / "wasm", DEST / "wasm", dirs_exist_ok=True)
    target = DEST / "hand_landmarker.task"
    expected = (ROOT / "scripts/model.sha256").read_text().split()[0]
    if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest() != expected:
        temporary = target.with_suffix(".download")
        subprocess.run(["curl", "--fail", "--silent", "--show-error", "--max-time", "90", "--proto", "=https", "-o", str(temporary), MODEL_URL], check=True)
        if hashlib.sha256(temporary.read_bytes()).hexdigest() != expected:
            temporary.unlink()
            raise SystemExit("Model checksum mismatch; no model was installed")
        temporary.replace(target)
    print("Pinned MediaPipe runtime and verified hand model are ready locally.")


if __name__ == "__main__":
    main()
