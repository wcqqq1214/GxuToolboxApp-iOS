#!/bin/bash
source "$(dirname "$0")/_env.sh"
cd "$ROOT"
source .secrets/account.env
SCREEN="$1"; MODE="${2:-light}"; shift 2 2>/dev/null || shift $#
[ "${SKIP_BUILD:-}" = 1 ] || ./scripts/build.sh >/dev/null 2>&1 || { echo "构建失败" >&2; exit 1; }
APP="$(find .build/Build/Products -maxdepth 3 -name GxuToolApp.app | head -1)"
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_ID" >/dev/null 2>&1
xcrun simctl install "$SIM_ID" "$APP"
export SIMCTL_CHILD_GXU_TEST_USER="$JW_USER" SIMCTL_CHILD_GXU_TEST_PASS="$JW_PASS"
xcrun simctl ui "$SIM_ID" appearance "$MODE"
xcrun simctl terminate "$SIM_ID" com.gxutool.ios 2>/dev/null || true
xcrun simctl launch "$SIM_ID" com.gxutool.ios -GxuScreen "$SCREEN" "$@" >/dev/null
sleep "${WAIT:-8}"
mkdir -p .screens
OUT=".screens/screen-$SCREEN-$MODE.png"
xcrun simctl io "$SIM_ID" screenshot "$OUT" >/dev/null 2>&1
echo "$ROOT/$OUT"
