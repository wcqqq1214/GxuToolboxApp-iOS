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

# 选模拟器：每个 worktree（按分支名）使用专属模拟器 "gxu-<分支名>"，不存在就创建，
# 这样多个 agent 同时跑 run-e2e 不会互相覆盖。可用 SIM_ID=<udid> 覆盖。
# 机型：最新的 "iPhone NN Pro"（排除 Pro Max / Duo / Fold / Flip / mini / Air）；runtime：最新的普通 iOS。
if [ -z "${SIM_ID:-}" ]; then
  BRANCH="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
  [ -z "$BRANCH" ] && BRANCH="detached"
  SIM_NAME="gxu-$(echo "$BRANCH" | tr '/ ' '--')"
  SIM_ID="$(xcrun simctl list devices available | grep -F "    $SIM_NAME (" | head -1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)"
  if [ -z "$SIM_ID" ]; then
    TYPE_ID="$(xcrun simctl list devicetypes | grep -E '^iPhone [0-9]+ Pro \(' \
      | sed -E 's/^iPhone ([0-9]+) Pro \((.*)\)$/\1 \2/' | sort -rn | head -1 | cut -d' ' -f2)"
    RUNTIME_ID="$(xcrun simctl list runtimes available | grep -E '^iOS ' | grep -vE 'iPhone[0-9]|Duo|Fold' \
      | sed -E 's/.* - (com\.apple\.CoreSimulator\.SimRuntime\.[^ ]+)$/\1/' | tail -1)"
    SIM_ID="$(xcrun simctl create "$SIM_NAME" "$TYPE_ID" "$RUNTIME_ID")"
  fi
fi
export SIM_ID
DESTINATION="platform=iOS Simulator,id=$SIM_ID"
