#!/bin/bash
# 构建 → 安装 → 带测试账号启动（DEBUG 自动登录）→ 截图。
# 账号来自 .secrets/account.env（JW_USER / JW_PASS），通过 SIMCTL_CHILD_ 前缀传给 App，不写日志、不进文件名。
# 用法：run-e2e.sh [light|dark|both]（默认 both）   环境变量：WAIT=秒（截图前等待，默认 10）
source "$(dirname "$0")/_env.sh"
cd "$ROOT"
set +x
source .secrets/account.env
MODES="${1:-both}"; [ "$MODES" = both ] && MODES="light dark"
WAIT="${WAIT:-10}"

./scripts/build.sh >/dev/null 2>&1 || { echo "构建失败，运行 scripts/build.sh 查看详情" >&2; exit 1; }
APP="$(find .build/Build/Products -maxdepth 3 -name GxuToolApp.app | head -1)"
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_ID" >/dev/null 2>&1
xcrun simctl install "$SIM_ID" "$APP"

export SIMCTL_CHILD_GXU_TEST_USER="$JW_USER"
export SIMCTL_CHILD_GXU_TEST_PASS="$JW_PASS"
mkdir -p .screens
STAMP="$(date +%H%M%S)"
for mode in $MODES; do
  xcrun simctl ui "$SIM_ID" appearance "$mode"
  xcrun simctl terminate "$SIM_ID" com.gxutool.ios 2>/dev/null || true
  xcrun simctl launch "$SIM_ID" com.gxutool.ios >/dev/null
  sleep "$WAIT"
  OUT=".screens/e2e-$mode-$STAMP.png"
  xcrun simctl io "$SIM_ID" screenshot "$OUT" >/dev/null 2>&1
  echo "$ROOT/$OUT"
done
