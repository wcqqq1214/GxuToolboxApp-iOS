#!/bin/bash
# 被 build.sh / test.sh source。选择 Xcode 和模拟器。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# xcode-select 指向 CommandLineTools 时，改用 /Applications/Xcode.app（不需要 sudo）
if ! xcrun --find simctl >/dev/null 2>&1; then
  for app in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    if [ -d "$app" ]; then export DEVELOPER_DIR="$app/Contents/Developer"; break; fi
  done
fi

# 优先 iPhone 17 Pro，没有就取第一台可用 iPhone
if [ -z "${SIM_ID:-}" ]; then
  DEVICES="$(xcrun simctl list devices available)"
  SIM_ID="$(echo "$DEVICES" | grep -E 'iPhone 17 Pro \(' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)"
  if [ -z "$SIM_ID" ]; then
    SIM_ID="$(echo "$DEVICES" | grep -E 'iPhone' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
  fi
fi
export SIM_ID
DESTINATION="platform=iOS Simulator,id=$SIM_ID"
