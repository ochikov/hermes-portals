#!/usr/bin/env python3
"""Check the tracked release tree, never local ignored runtime data."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
files = subprocess.check_output(
    ["git", "ls-files", "-z"], cwd=ROOT
).decode().split("\0")
blocked_dirs = {".runtime", ".venv", "node_modules", "__pycache__", "vendor", "build"}
blocked_suffixes = {".pyc", ".pyo", ".sqlite3", ".db", ".wasm", ".dylib", ".so",
                    ".exe", ".dll", ".zip", ".gz", ".dmg", ".task"}
executable_magic = (b"\x7fELF", b"MZ", b"\x00asm", b"\xcf\xfa\xed\xfe",
                    b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xce\xfa\xed\xfe")
private_patterns = [
    re.compile(rb"/Users/[A-Za-z0-9_.-]+/"),
    re.compile(rb"/home/[A-Za-z0-9_.-]+/"),
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(rb"(?:ghp_|github_pat_)[A-Za-z0-9_]{25,}"),
    re.compile(rb"#(?:owner|pair)=[A-Za-z0-9_-]{24,}"),
]
failures = []
for name in filter(None, files):
    path = ROOT / name
    if blocked_dirs.intersection(Path(name).parts) or path.suffix in blocked_suffixes:
        failures.append(f"{name}: generated, private or executable payload")
        continue
    if path.is_symlink():
        failures.append(f"{name}: release must not include symlinks")
        continue
    content = path.read_bytes()
    if content.startswith(executable_magic):
        failures.append(f"{name}: executable file header")
    if path.suffix.lower() not in {".png", ".jpg", ".jpeg"}:
        if any(pattern.search(content) for pattern in private_patterns):
            failures.append(f"{name}: private path or credential-like text; review locally")

if not any(files):
    failures.append("No tracked files; stage the intended release tree first.")
if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)
print(f"Release source check passed ({sum(bool(name) for name in files)} tracked files).")
