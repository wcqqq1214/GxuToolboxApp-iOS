#!/bin/bash
# 在真机上构建、安装、启动（Debug，用真实 Team ID 自动签名；真机不能用 ad-hoc 签名）。
# 用法：
#   scripts/run-device.sh --check            只检查前置条件（Team ID、devicectl、已连接设备），不构建
#   scripts/run-device.sh                    构建 App + Widget → 安装 → 启动（只有一台设备时自动选择）
#   scripts/run-device.sh --device <名称或UDID>   有多台设备时指定
#   scripts/run-device.sh --no-launch        只安装不启动
# Team ID：环境变量 DEVELOPMENT_TEAM，或 .secrets/archive.env（已 gitignore）里的 DEVELOPMENT_TEAM=...；
#   不会写进 git，project.yml 里保持占位符 YOUR_TEAM_ID，由本脚本在命令行覆盖。
# 前提：设备已用数据线连接并信任此电脑、开启开发者模式；Apple ID 已登录 Xcode；付费的 Apple Developer Program 账号
#   （App Group、Live Activities、Keychain 共享都需要，免费个人账号做不到）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# xcode-select 指向 CommandLineTools 时，改用 /Applications/Xcode.app（和 _env.sh 一致）
if ! xcrun --find devicectl >/dev/null 2>&1; then
  for app in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    if [ -d "$app" ]; then export DEVELOPER_DIR="$app/Contents/Developer"; break; fi
  done
fi

CHECK_ONLY=0; LAUNCH=1; WANT_DEVICE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --no-launch) LAUNCH=0 ;;
    --device) shift; WANT_DEVICE="${1:-}"; [ -n "$WANT_DEVICE" ] || { echo "--device 需要一个设备名称或 UDID" >&2; exit 2; } ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "未知参数：$1（见 --help）" >&2; exit 2 ;;
  esac
  shift
done

errors=()
fail() { errors+=("$1"); }

# 1. 工具
command -v xcodegen >/dev/null || fail "找不到 xcodegen（brew install xcodegen）"
xcrun --find devicectl >/dev/null 2>&1 || fail "找不到 devicectl：请安装 Xcode 15 或更新版本"

# 2. Team ID：命令行环境变量 > .secrets/archive.env > project.yml（占位符不算）。环境变量显式给了就不能被文件覆盖
ENV_TEAM="${DEVELOPMENT_TEAM:-}"
FILE_TEAM=""
if [ -f .secrets/archive.env ]; then
  FILE_TEAM="$(sed -n 's/^ *DEVELOPMENT_TEAM *= *"\{0,1\}\([A-Za-z0-9]*\)"\{0,1\} *\(#.*\)\{0,1\}$/\1/p' .secrets/archive.env | tail -1)"
fi
TEAM="${ENV_TEAM:-$FILE_TEAM}"
if [ -z "$TEAM" ]; then
  fail "还没有填写 Apple Developer Team ID。请设置环境变量 DEVELOPMENT_TEAM=<10 位 Team ID>，或写进 .secrets/archive.env（DEVELOPMENT_TEAM=...）。Team ID 在 developer.apple.com → Membership 里查看。真实 Team ID 不会写进 git。"
elif ! [[ "$TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
  fail "Team ID 格式不对：应为 10 位大写字母或数字，现在是「${TEAM}」"
fi

# 3. 已连接的设备（devicectl 的 JSON 输出）
DEVICES_JSON="$(mktemp)"; trap 'rm -f "$DEVICES_JSON"' EXIT
DEVICE_LINES=""
if xcrun --find devicectl >/dev/null 2>&1; then
  if xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1; then
    DEVICE_LINES="$(python3 -I - "$DEVICES_JSON" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1])).get("result", {}).get("devices", [])
except Exception:
    devices = []
for d in devices:
    hw, props, conn = d.get("hardwareProperties", {}), d.get("deviceProperties", {}), d.get("connectionProperties", {})
    # 只要真机：devicectl 也会列出本机的模拟器（reality = "simulated"），要排除
    if hw.get("platform") != "iOS" or hw.get("reality") == "simulated":
        continue
    if conn.get("tunnelState") not in ("connected", "available"):
        continue
    print("\t".join([hw.get("udid", d.get("identifier", "")), props.get("name", "?"), hw.get("marketingName", ""), props.get("osVersionNumber", "")]))
PY
)"
  else
    fail "devicectl list devices 失败（Xcode 命令行工具异常？）"
  fi
fi
CHOSEN_UDID=""; CHOSEN_NAME=""
if [ -z "$DEVICE_LINES" ]; then
  fail "没有找到已连接的 iPhone：请用数据线连接、解锁、信任此电脑，并在「设置 → 隐私与安全性」里开启开发者模式"
else
  COUNT="$(printf '%s\n' "$DEVICE_LINES" | wc -l | tr -d ' ')"
  if [ -n "$WANT_DEVICE" ]; then
    LINE="$(printf '%s\n' "$DEVICE_LINES" | awk -F'\t' -v w="$WANT_DEVICE" '$1==w || $2==w {print; exit}')"
    [ -n "$LINE" ] || fail "没有名为或 UDID 为「${WANT_DEVICE}」的已连接设备。已连接：$(printf '%s\n' "$DEVICE_LINES" | awk -F'\t' '{printf "%s(%s) ", $2, $1}')"
  elif [ "$COUNT" -eq 1 ]; then
    LINE="$DEVICE_LINES"
  else
    LINE=""
    fail "有 ${COUNT} 台设备，请用 --device 指定：$(printf '%s\n' "$DEVICE_LINES" | awk -F'\t' '{printf "%s(%s) ", $2, $1}')"
  fi
  if [ -n "${LINE:-}" ]; then
    CHOSEN_UDID="$(printf '%s' "$LINE" | cut -f1)"; CHOSEN_NAME="$(printf '%s' "$LINE" | cut -f2)"
  fi
fi

if [ ${#errors[@]} -gt 0 ]; then
  echo "真机运行前检查未通过：" >&2
  for e in "${errors[@]}"; do echo "  ✗ $e" >&2; done
  exit 1
fi
echo "前置检查通过：Team ${TEAM}，设备 ${CHOSEN_NAME}（${CHOSEN_UDID}）"
[ "$CHECK_ONLY" = 1 ] && exit 0

# 4. 构建（App 依赖 Widget，一起构建）。用 Team ID 自动签名，不加 CODE_SIGN_IDENTITY="-"（那是模拟器的 ad-hoc 签名）
xcodegen generate --quiet
DD="$ROOT/.build-device"
xcodebuild -project GxuToolApp.xcodeproj -scheme GxuToolApp -configuration Debug \
  -destination "id=${CHOSEN_UDID}" -derivedDataPath "$DD" \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates build -quiet
APP="$(find "$DD/Build/Products" -maxdepth 2 -name GxuToolApp.app | head -1)"
[ -n "$APP" ] || { echo "构建完成但找不到 GxuToolApp.app" >&2; exit 1; }

# 5. 安装、启动
xcrun devicectl device install app --device "$CHOSEN_UDID" "$APP"
if [ "$LAUNCH" = 1 ]; then
  xcrun devicectl device process launch --device "$CHOSEN_UDID" --terminate-existing com.gxutool.ios
  echo "已在 ${CHOSEN_NAME} 上启动。真机上请手动登录各账号（脚本不会传递任何账号密码）。"
else
  echo "已安装到 ${CHOSEN_NAME}（未启动）。"
fi
