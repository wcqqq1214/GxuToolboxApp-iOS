#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! xcrun --find simctl >/dev/null 2>&1; then
  for app in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    if [ -d "$app" ]; then export DEVELOPER_DIR="$app/Contents/Developer"; break; fi
  done
fi

if [ -z "${SIM_ID:-}" ]; then
  BRANCH="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
  if [ -z "$BRANCH" ]; then
    GIT_DIR_PATH="$(git -C "$ROOT" rev-parse --absolute-git-dir 2>/dev/null || true)"
    for f in "$GIT_DIR_PATH/rebase-merge/head-name" "$GIT_DIR_PATH/rebase-apply/head-name"; do
      [ -f "$f" ] && BRANCH="$(sed 's#^refs/heads/##' "$f")" && break
    done
    [ -z "$BRANCH" ] && BRANCH="$(basename "$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$ROOT")")"
  fi
  SUFFIX="$(printf '%s' "$BRANCH" | tr -c 'A-Za-z0-9._' '-' | sed -e 's/^-*//' -e 's/-*$//')"
  if [ -z "$SUFFIX" ] || ! [[ "$SUFFIX" =~ [A-Za-z0-9] ]] || [ ! -f "$ROOT/project.yml" ]; then
    echo "无法确定本 worktree 的专属模拟器名（分支名「$BRANCH」，目录「$ROOT」）。请在 iOS 工程所在的工作区运行，或用 SIM_ID=<udid> 指定模拟器。" >&2
    exit 1
  fi
  SIM_NAME="gxu-$SUFFIX"
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
