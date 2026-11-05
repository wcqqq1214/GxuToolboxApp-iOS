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

# 选模拟器：优先最新的 "iPhone NN Pro"（排除 Pro Max），其次最新的普通 "iPhone NN"；
# 始终排除 Duo / Fold / Flip / mini / Air / e 等特殊机型。可用 SIM_ID=<udid> 覆盖。
if [ -z "${SIM_ID:-}" ]; then
  DEVICES="$(xcrun simctl list devices available | grep -E '^\s+iPhone ')"
  pick() { # $1 = 机型名正则（NN 为数字）
    echo "$DEVICES" | grep -E "^\s+$1 \(" | grep -vE 'Duo|Fold|Flip|mini' \
      | sed -E 's/^ +iPhone ([0-9]+).*\(([0-9A-F-]{36})\).*/\1 \2/' | sort -rn | head -1 | cut -d' ' -f2
  }
  SIM_ID="$(pick 'iPhone [0-9]+ Pro')"
  [ -z "$SIM_ID" ] && SIM_ID="$(pick 'iPhone [0-9]+')"
  [ -z "$SIM_ID" ] && SIM_ID="$(echo "$DEVICES" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
fi
export SIM_ID
DESTINATION="platform=iOS Simulator,id=$SIM_ID"
