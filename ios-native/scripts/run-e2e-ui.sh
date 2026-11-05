#!/bin/bash
# 用 XCUITest 在真实后端上走完整流程并逐步截图。账号读自 .secrets/account.env。
# 用法：run-e2e-ui.sh [light|dark] [phase1|phase2]（默认 phase1）   截图目录：.screens/ui-<mode>-<时间>/（phase2 带 phase2-report.txt）
source "$(dirname "$0")/_env.sh"
cd "$ROOT"
source .secrets/account.env
MODE="${1:-light}"
CASE="${2:-phase1}"
[ "$CASE" = phase2 ] && ONLY="GxuToolAppUITests/E2EWalkthroughTests/testPhase2" || ONLY="GxuToolAppUITests/E2EWalkthroughTests/testWalkthrough"
xcodegen generate --quiet
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_ID" >/dev/null 2>&1
xcrun simctl ui "$SIM_ID" appearance "$MODE"
DIR="$ROOT/.screens/ui-$MODE-$(date +%H%M%S)"
export TEST_RUNNER_GXU_TEST_USER="$JW_USER" TEST_RUNNER_GXU_TEST_PASS="$JW_PASS" TEST_RUNNER_GXU_SHOT_DIR="$DIR"
xcodebuild -project GxuToolApp.xcodeproj -scheme GxuToolApp -destination "$DESTINATION" -derivedDataPath .build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES -only-testing:"$ONLY" test -quiet 2>&1 | tail -30
echo "截图：$DIR"
