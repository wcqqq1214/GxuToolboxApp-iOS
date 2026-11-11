#!/bin/bash
source "$(dirname "$0")/_env.sh"
cd "$ROOT"
source .secrets/account.env
MODE="${1:-light}"
CASE="${2:-phase1}"
[ "${3:-}" = legacy ] && export TEST_RUNNER_GXU_FORCE_LEGACY=1 && TAG="-legacy" || TAG=""
case "$CASE" in
  phase3) ONLY="GxuToolAppUITests/E2EWalkthroughTests/testPhase3" ;;
  phase2) ONLY="GxuToolAppUITests/E2EWalkthroughTests/testPhase2" ;;
  *)      ONLY="GxuToolAppUITests/E2EWalkthroughTests/testWalkthrough" ;;
esac
xcodegen generate --quiet
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_ID" >/dev/null 2>&1
xcrun simctl ui "$SIM_ID" appearance "$MODE"
DIR="$ROOT/.screens/ui-$MODE$TAG-$(date +%H%M%S)"
export TEST_RUNNER_GXU_TEST_USER="$JW_USER" TEST_RUNNER_GXU_TEST_PASS="$JW_PASS" TEST_RUNNER_GXU_SHOT_DIR="$DIR"
xcodebuild -project GxuToolApp.xcodeproj -scheme GxuToolApp -destination "$DESTINATION" -derivedDataPath .build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES -only-testing:"$ONLY" test -quiet 2>&1 | tail -30
echo "截图：$DIR"
