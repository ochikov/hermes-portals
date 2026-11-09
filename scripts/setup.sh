#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_build_mac=false
case "${1:-}" in
  --with-mac) task_build_mac=true ;;
  --help|-h)
    echo "Usage: ./scripts/setup.sh [--with-mac]"
    echo "Installs the isolated companion and pinned browser assets."
    echo "--with-mac also builds the optional Mac controller from source."
    exit 0 ;;
  "") ;;
  *) echo "Unknown option. Use --help." >&2; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then echo "Use --help for setup options." >&2; exit 2; fi
for task_tool in uv npm curl; do
  if ! command -v "$task_tool" >/dev/null 2>&1; then
    echo "Missing prerequisite: $task_tool. See README.md." >&2
    exit 1
  fi
done
if $task_build_mac; then
  if [[ "$(uname -s)" != "Darwin" ]] || ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "--with-mac needs macOS 13+ and Xcode Command Line Tools." >&2
    exit 1
  fi
fi
if [[ ! -x .venv/bin/python ]]; then uv venv --python 3.11 .venv; fi
uv pip sync --python .venv/bin/python --require-hashes requirements.lock
npm ci --ignore-scripts --no-fund --no-audit
.venv/bin/python scripts/prepare_assets.py
if $task_build_mac; then
  ./scripts/build_macos.sh
fi
echo "Ready. Use Hermes /portals start <laptop-LAN-IP>, or scripts/portals.py."
