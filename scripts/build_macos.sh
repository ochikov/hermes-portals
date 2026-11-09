#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != "Darwin" ]]; then echo "The native controller requires macOS." >&2; exit 1; fi
task_build="native/macos/build/Hermes Portals Control.app"
mkdir -p "$task_build/Contents/MacOS"
xcrun swiftc -swift-version 5 -O -target "$(uname -m)-apple-macosx13.0" \
  -framework AppKit -framework AVFoundation -framework ApplicationServices -framework Vision \
  native/macos/GestureEngine.swift native/macos/EngineTests.swift native/macos/Localization.swift native/macos/TrackingPreview.swift native/macos/main.swift \
  -o "$task_build/Contents/MacOS/HermesPortalsControl"
cp native/macos/Info.plist "$task_build/Contents/Info.plist"
codesign --force --sign - --identifier com.hermesportals.control "$task_build"
"$task_build/Contents/MacOS/HermesPortalsControl" --self-test
echo "Built: $PWD/$task_build"
