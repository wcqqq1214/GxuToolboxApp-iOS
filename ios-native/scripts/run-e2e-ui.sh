#!/bin/bash
# 用 XCUITest 在真实后端上走完整流程并逐步截图。账号读自 .secrets/account.env。
# 用法：run-e2e-ui.sh [light|dark]   截图目录：.screens/ui-<mode>-<时间>/
source "$(dirname "$0")/_env.sh"
cd "$ROOT"
source .secrets/account.env
MODE="${1:-light}"
xcodegen generate --quiet
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_ID" >/dev/null 2>&1
xcrun simctl ui "$SIM_ID" appearance "$MODE"
DIR="$ROOT/.screens/ui-$MODE-$(date +%H%M%S)"
export TEST_RUNNER_GXU_TEST_USER="$JW_USER" TEST_RUNNER_GXU_TEST_PASS="$JW_PASS" TEST_RUNNER_GXU_SHOT_DIR="$DIR"
xcodebuild -project GxuToolApp.xcodeproj -scheme GxuToolApp -destination "$DESTINATION" -derivedDataPath .build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES -only-testing:GxuToolAppUITests test -quiet 2>&1 | tail -30
echo "截图：$DIR"
