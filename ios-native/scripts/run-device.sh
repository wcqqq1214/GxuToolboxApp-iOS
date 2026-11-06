#!/bin/bash
# 在真机上构建、安装、启动（Debug，自动签名；真机不能用 ad-hoc 签名）。
# 用法：
#   scripts/run-device.sh --check            只检查前置条件（Team ID、devicectl、已连接设备），不构建
#   scripts/run-device.sh                    构建 App + Widget → 安装 → 启动（只有一台设备时自动选择）
#   scripts/run-device.sh --device <名称或UDID>   有多台设备时指定
#   scripts/run-device.sh --no-launch        只安装不启动
#   scripts/run-device.sh --personal         免费 Apple 账号（个人团队）模式：见下
#   scripts/run-device.sh --ipa              不连设备也行：自动签名导出 development 方法的 .ipa 到 build/export/，
#                                            结束时打印它的绝对路径和安装方式（让别人自己装）。需要付费账号，不能和 --personal 一起用
#                                            .ipa 只能装在 development 描述文件里登记过 UDID 的设备上：先把 iPhone 用数据线连一次
#                                            （Xcode 会自动登记），或在 developer.apple.com → Devices 里手动添加 UDID
#
# --personal（免费账号）：
#   - Team ID 不用手填：从 Xcode 登录的账号（优先免费个人团队）或钥匙串里的 Apple Development 证书自动取；取到多个会列出（只显示打码的 ID），
#     用 DEVELOPMENT_TEAM=<完整 ID> 指定；取不到会提示怎么办。真实 ID 不会打印、不会写进 git。
#   - 先按完整能力（App Group + Keychain 共享）签名；Xcode 报「个人团队不支持」才自动改用去掉这两项 entitlements 的 Debug 构建
#     （App 和小组件各用自己的容器，小组件读不到 App 的数据），并打印实际结论。降级只对这次 --personal 构建生效，不改 project.yml。
#   - 免费账号的描述文件 7 天过期：过期后 App 打不开，重新运行本脚本即可；TestFlight 和 archive.sh 上传需要付费账号。
#
# 配置（环境变量，或 .secrets/archive.env 里的同名项；环境变量优先；都不会写进 git）：
#   DEVELOPMENT_TEAM   10 位 Team ID（--personal 可以不填）
#   BUNDLE_ID          覆盖 App 的 Bundle ID，默认 com.gxutool.ios；Widget 自动用 <BUNDLE_ID>.widget，App Group 用 group.<BUNDLE_ID>。
#                      如果提示 com.gxutool.ios 已被别的团队占用，换成 com.<你的名字>.gxutool 之类
# 前提：设备已用数据线连接并信任此电脑、开启开发者模式；Apple ID 已登录 Xcode。付费账号才有 App Group / Live Activities / TestFlight 的完整支持。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# xcode-select 指向 CommandLineTools 时，改用 /Applications/Xcode.app（和 _env.sh 一致）
if ! xcrun --find devicectl >/dev/null 2>&1; then
  for app in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    if [ -d "$app" ]; then export DEVELOPER_DIR="$app/Contents/Developer"; break; fi
  done
fi

# Xcode 签名失败时日志里的关键句（降级和提示都靠它们，所以单独放这里，--self-test 会用 Apple 的真实措辞测一遍）
UNSUPPORTED_RE='(personal (development )?teams?.*(not support|n.t support)|(app groups?|keychain sharing|application-groups|keychain-access-groups).*(not support|n.t support|unsupported|not available|unavailable)|(not support|n.t support|unsupported|not available).*(app groups?|keychain sharing))'
BUNDLE_TAKEN_RE='cannot be registered|is not available\. Change your bundle|bundle identifier.*(not available|already)'

CHECK_ONLY=0; LAUNCH=1; WANT_DEVICE=""; IPA=0; PERSONAL=0; SELF_TEST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --no-launch) LAUNCH=0 ;;
    --ipa) IPA=1 ;;
    --personal) PERSONAL=1 ;;
    --self-test) SELF_TEST=1 ;;
    --device) shift; WANT_DEVICE="${1:-}"; [ -n "$WANT_DEVICE" ] || { echo "--device 需要一个设备名称或 UDID" >&2; exit 2; } ;;
    -h|--help) sed -n '2,31p' "$0"; exit 0 ;;
    *) echo "未知参数：$1（见 --help）" >&2; exit 2 ;;
  esac
  shift
done
errors=()
fail() { errors+=("$1"); }
mask() { local t="$1"; printf '%s' "${t:0:2}********"; }

if [ "$SELF_TEST" = 1 ]; then
  ok=1
  expect() { # expect <yes|no> <正则> <文本>
    if printf '%s' "$3" | grep -Eiq "$2"; then got=yes; else got=no; fi
    [ "$got" = "$1" ] || { echo "  ✗ 期望 $1，实际 ${got}：${3}" >&2; ok=0; }
  }
  expect yes "$UNSUPPORTED_RE" 'error: Personal development teams, including "Someone", do not support the App Groups capability.'
  expect yes "$UNSUPPORTED_RE" 'error: Personal development teams do not support the Keychain Sharing capability.'
  expect yes "$UNSUPPORTED_RE" 'Provisioning profile "iOS Team Provisioning Profile: com.x.y" doesn'"'"'t support the App Groups capability.'
  expect yes "$UNSUPPORTED_RE" 'The Keychain Sharing capability is not supported for this team'
  expect no  "$UNSUPPORTED_RE" 'error: No Account for Team "ABCDE12345". Add a new account in the Accounts preference pane.'
  expect no  "$UNSUPPORTED_RE" 'error: Signing for "GxuToolApp" requires a development team.'
  expect no  "$UNSUPPORTED_RE" 'warning: The App Groups entitlement is present'
  expect yes "$BUNDLE_TAKEN_RE" 'Failed Registering Bundle Identifier: The app identifier "com.gxutool.ios" cannot be registered to your development team because it is not available. Change your bundle identifier to a unique string and try again.'
  expect no  "$BUNDLE_TAKEN_RE" 'error: Communication with Apple failed'
  [ "$(mask ABCDE12345)" = "AB********" ] || { echo "  ✗ mask" >&2; ok=0; }
  [ "$ok" = 1 ] && { echo "run-device self-test OK"; exit 0; } || exit 1
fi
if [ "$PERSONAL" = 1 ] && [ "$IPA" = 1 ]; then
  echo "--personal 不能和 --ipa 一起用：免费个人团队导出不了 development 的 .ipa，请直接用 --personal 安装到连接的手机。" >&2
  exit 2
fi


# 从 .secrets/archive.env 里读 KEY=值（不 source，避免执行文件里的任意命令）
file_value() {
  [ -f .secrets/archive.env ] || return 0
  sed -n "s/^ *$1 *= *\"\{0,1\}\([A-Za-z0-9._-]*\)\"\{0,1\} *\(#.*\)\{0,1\}$/\1/p" .secrets/archive.env | tail -1
}

# 1. 工具
command -v xcodegen >/dev/null || fail "找不到 xcodegen（brew install xcodegen）"
xcrun --find devicectl >/dev/null 2>&1 || fail "找不到 devicectl：请安装 Xcode 15 或更新版本"

# 2. Bundle ID：环境变量 > .secrets/archive.env > 默认值
BUNDLE_ID="${BUNDLE_ID:-$(file_value BUNDLE_ID)}"; BUNDLE_ID="${BUNDLE_ID:-com.gxutool.ios}"
if ! [[ "$BUNDLE_ID" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  fail "BUNDLE_ID 格式不对：应为反向域名，例如 com.alice.gxutool，现在是「${BUNDLE_ID}」"
fi

# 3. Team ID：环境变量 > .secrets/archive.env >（--personal）自动检测
TEAM="${DEVELOPMENT_TEAM:-$(file_value DEVELOPMENT_TEAM)}"
TEAM_NOTE=""
if [ -z "$TEAM" ] && [ "$PERSONAL" = 1 ]; then
  CANDIDATES="$(python3 -I "$ROOT/scripts/detect-team.py" 2>/dev/null || true)"
  COUNT="$(printf '%s' "$CANDIDATES" | grep -c . || true)"
  FREE_COUNT="$(printf '%s' "$CANDIDATES" | awk -F'\t' '$2=="free"' | grep -c . || true)"
  if [ "$COUNT" -eq 0 ]; then
    fail "没有从 Xcode 账号或钥匙串里找到 Apple 开发团队。请：① 打开 Xcode → Settings → Accounts，用 Apple ID 登录；② 在 Xcode 里随便新建一个 iOS 项目，Signing 里选你的 Personal Team，连着手机运行一次（会生成 Apple Development 证书）；③ 再运行本脚本。也可以直接设置 DEVELOPMENT_TEAM=<10 位 Team ID>"
  elif [ "$FREE_COUNT" -eq 1 ]; then
    TEAM="$(printf '%s' "$CANDIDATES" | awk -F'\t' '$2=="free"{print $1}')"; TEAM_NOTE="（自动检测：免费个人团队）"
  elif [ "$COUNT" -eq 1 ]; then
    TEAM="$(printf '%s' "$CANDIDATES" | cut -f1)"; TEAM_NOTE="（自动检测：唯一的团队）"
  else
    LIST="$(printf '%s\n' "$CANDIDATES" | while IFS=$'\t' read -r id kind src; do printf '%s[%s] ' "$(mask "$id")" "$kind"; done)"
    fail "找到多个团队：${LIST}。请用 DEVELOPMENT_TEAM=<完整 Team ID> 指定一个（完整 ID 在 Xcode → Settings → Accounts → 选中团队，或 developer.apple.com → Membership）"
  fi
fi
if [ -z "$TEAM" ]; then
  if [ "$PERSONAL" != 1 ]; then
    fail "还没有填写 Apple Developer Team ID。请设置环境变量 DEVELOPMENT_TEAM=<10 位 Team ID>，或写进 .secrets/archive.env（可以从 .secrets/archive.env.example 复制）。Team ID 在 developer.apple.com → Membership 里查看；只有免费账号请加 --personal 让脚本自动检测。真实 Team ID 不会写进 git。"
  fi
elif ! [[ "$TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
  fail "Team ID 格式不对：应为 10 位大写字母或数字（长度 ${#TEAM}）"
fi

# 4. 已连接的设备（devicectl 的 JSON 输出）。state：connected / offline（已配对但 Xcode 看到的是离线）
DEVICES_JSON="$(mktemp)"; trap 'rm -f "$DEVICES_JSON"' EXIT
ALL_LINES=""
if xcrun --find devicectl >/dev/null 2>&1; then
  if xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1; then
    ALL_LINES="$(python3 -I - "$DEVICES_JSON" <<'PY'
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
    state = "connected" if conn.get("tunnelState") in ("connected", "available") else "offline"
    print("\t".join([hw.get("udid", d.get("identifier", "")), props.get("name", "?"), hw.get("marketingName", ""), props.get("osVersionNumber", ""), state]))
PY
)"
  else
    fail "devicectl list devices 失败（Xcode 命令行工具异常？）"
  fi
fi
DEVICE_LINES="$(printf '%s\n' "$ALL_LINES" | awk -F'\t' '$5=="connected"')"
OFFLINE_NAMES="$(printf '%s\n' "$ALL_LINES" | awk -F'\t' '$5=="offline"{printf "%s ", $2}')"
CHOSEN_UDID=""; CHOSEN_NAME=""
if [ "$IPA" = 1 ]; then
  :   # 导出 .ipa 不需要设备在线
elif [ -z "$DEVICE_LINES" ]; then
  if [ -n "$OFFLINE_NAMES" ]; then
    fail "设备已配对但现在是离线状态：${OFFLINE_NAMES}。请解锁手机、点「信任」、换一根数据线 / 接口；Xcode → Window → Devices and Simulators 里应该显示 Connected（第一次连接要等 Xcode 处理完「准备设备」）；无线连接的设备要在同一个 Wi-Fi"
  else
    fail "没有找到已连接的 iPhone：请用数据线连接、解锁、信任此电脑，并在「设置 → 隐私与安全性」里开启开发者模式"
  fi
else
  COUNT="$(printf '%s\n' "$DEVICE_LINES" | wc -l | tr -d ' ')"
  LINE=""
  if [ -n "$WANT_DEVICE" ]; then
    LINE="$(printf '%s\n' "$DEVICE_LINES" | awk -F'\t' -v w="$WANT_DEVICE" '$1==w || $2==w {print; exit}')"
    [ -n "$LINE" ] || fail "没有名为或 UDID 为「${WANT_DEVICE}」的已连接设备。已连接：$(printf '%s\n' "$DEVICE_LINES" | awk -F'\t' '{printf "%s(%s) ", $2, $1}')"
  elif [ "$COUNT" -eq 1 ]; then
    LINE="$DEVICE_LINES"
  else
    fail "有 ${COUNT} 台设备，请用 --device 指定：$(printf '%s\n' "$DEVICE_LINES" | awk -F'\t' '{printf "%s(%s) ", $2, $1}')"
  fi
  if [ -n "$LINE" ]; then CHOSEN_UDID="$(printf '%s' "$LINE" | cut -f1)"; CHOSEN_NAME="$(printf '%s' "$LINE" | cut -f2)"; fi
fi

if [ ${#errors[@]} -gt 0 ]; then
  echo "真机运行前检查未通过：" >&2
  for e in "${errors[@]}"; do echo "  ✗ $e" >&2; done
  exit 1
fi
MODE_NOTE="完整能力"; [ "$PERSONAL" = 1 ] && MODE_NOTE="免费账号（--personal）"; [ "$IPA" = 1 ] && MODE_NOTE="导出 .ipa（development）"
if [ "$IPA" = 1 ]; then
  echo "前置检查通过：Team $(mask "$TEAM")${TEAM_NOTE}，Bundle ID ${BUNDLE_ID}，模式 ${MODE_NOTE}"
  [ -n "$DEVICE_LINES" ] || echo "提示：现在没有连接的 iPhone。.ipa 只能装在 development 描述文件里登记过 UDID 的设备上，建议先把手机连一次电脑让 Xcode 自动登记。"
else
  echo "前置检查通过：Team $(mask "$TEAM")${TEAM_NOTE}，设备 ${CHOSEN_NAME}，Bundle ID ${BUNDLE_ID}，模式 ${MODE_NOTE}"
fi
[ "$CHECK_ONLY" = 1 ] && exit 0

COMMON=(DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic GXU_BUNDLE_ID="$BUNDLE_ID")
mkdir -p "$ROOT/build"
xcodegen generate --quiet

# ---- 导出 .ipa（development）：archive → exportArchive，自动签名 ----
if [ "$IPA" = 1 ]; then
  ARCHIVE="$ROOT/build/GxuToolApp-dev.xcarchive"; EXPORT_DIR="$ROOT/build/export"
  rm -rf "$ARCHIVE" "$EXPORT_DIR"
  # Debug 配置：开发安装用，不会上报埋点（Release 才上报），也保留调试入口；真机用自动签名，不是 ad-hoc
  xcodebuild -project GxuToolApp.xcodeproj -scheme GxuToolApp -configuration Debug \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" "${COMMON[@]}" -allowProvisioningUpdates archive -quiet
  OPTIONS="$ROOT/build/ExportOptions-dev.plist"
  cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>development</string>
  <key>teamID</key><string>${TEAM}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
  <key>compileBitcode</key><false/>
</dict></plist>
PLIST
  plutil -lint "$OPTIONS" >/dev/null
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTIONS" -exportPath "$EXPORT_DIR" -allowProvisioningUpdates
  IPA_PATH="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' | head -1)"
  [ -n "$IPA_PATH" ] || { echo "导出完成但找不到 .ipa（见 ${EXPORT_DIR}）" >&2; exit 1; }
  cat <<DONE

已导出：${IPA_PATH}

安装方式（任选一种；手机必须是 development 描述文件里登记过 UDID 的设备）：
  1. Xcode：菜单 Window → Devices and Simulators → 选中已连接的 iPhone → 在「Installed Apps」下点 + → 选这个 .ipa
  2. Apple Configurator（Mac App Store 免费）：连接 iPhone → 双击设备 → Add → Apps → 选这个 .ipa
  3. 命令行：xcrun devicectl device install app --device <设备名或UDID> "${IPA_PATH}"
首次打开提示「不受信任的开发者」时：设置 → 通用 → VPN 与设备管理 → 信任你的开发者账号。
DONE
  exit 0
fi

# ---- 构建（App 依赖 Widget，一起构建）。用 Team ID 自动签名，不加 CODE_SIGN_IDENTITY="-"（那是模拟器的 ad-hoc 签名）----
DD="$ROOT/.build-device"
LOG="$ROOT/build/device-build.log"
build() {   # build [额外 xcodebuild 设置...]
  xcodebuild -project GxuToolApp.xcodeproj -scheme GxuToolApp -configuration Debug \
    -destination "id=${CHOSEN_UDID}" -derivedDataPath "$DD" "${COMMON[@]}" "$@" -allowProvisioningUpdates build
}

if [ "$PERSONAL" = 1 ]; then
  # 不预设个人团队支持什么：先按完整能力（App Group + Keychain 共享）签名
  CAPABILITY="完整能力（App Group + Keychain 共享）"
  if ! build > "$LOG" 2>&1; then
    if grep -Eiq "$UNSUPPORTED_RE" "$LOG"; then
      echo "Xcode 报告：个人团队不支持 App Group / Keychain 共享。改用去掉 application-groups 和 keychain-access-groups 的 Debug 构建重试（只对这次 --personal 构建生效）……"
      EMPTY_ENT="$ROOT/build/personal-empty.entitlements"
      cat > "$EMPTY_ENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict/></plist>
PLIST
      if build CODE_SIGN_ENTITLEMENTS="$EMPTY_ENT" GXU_APP_GROUP= GXU_KEYCHAIN_GROUP= > "$LOG" 2>&1; then
        CAPABILITY="降级（没有 App Group 和共享 Keychain）"
      else
        FAILED_DEGRADED=1
      fi
    else
      FAILED_DEGRADED=1
    fi
    if [ "${FAILED_DEGRADED:-0}" = 1 ]; then
      echo "构建 / 签名失败。相关错误（完整日志：${LOG}）：" >&2
      grep -E "error:" "$LOG" | sed 's/^[^ ]* //' | sort -u | head -8 >&2
      if grep -Eiq "$BUNDLE_TAKEN_RE" "$LOG"; then
        echo "→ Bundle ID「${BUNDLE_ID}」已被别的团队占用。请设置 BUNDLE_ID=com.<你的名字>.gxutool（环境变量或 .secrets/archive.env）后重新运行。" >&2
      fi
      if grep -Eiq 'No Account for Team|no accounts|Add your account' "$LOG"; then
        echo "→ Xcode 里没有这个团队的账号：Xcode → Settings → Accounts 登录 Apple ID。" >&2
      fi
      if grep -Eiq 'maximum number of (apps|app ids)|too many|10 App IDs' "$LOG"; then
        echo "→ 免费账号每周能注册的 App ID 数量有限，等几天再试，或换一个 BUNDLE_ID 复用已注册的。" >&2
      fi
      exit 1
    fi
  fi
  echo "实际结论：个人团队 ${CAPABILITY}。"
  [[ "$CAPABILITY" == 降级* ]] && echo "  → 小组件读不到 App 的数据（显示「未就绪」），App 自己的数据和登录不受影响；清单里小组件、App Group 共享、Keychain 共享这几项在 --personal 下验证不了。"
else
  build -quiet
fi
APP="$(find "$DD/Build/Products" -maxdepth 2 -name GxuToolApp.app | head -1)"
[ -n "$APP" ] || { echo "构建完成但找不到 GxuToolApp.app" >&2; exit 1; }

# ---- 安装、启动 ----
xcrun devicectl device install app --device "$CHOSEN_UDID" "$APP"
if [ "$LAUNCH" = 1 ]; then
  xcrun devicectl device process launch --device "$CHOSEN_UDID" --terminate-existing "$BUNDLE_ID" || \
    echo "安装成功但启动失败（多半是手机还没信任开发者）：设置 → 通用 → VPN 与设备管理 → 信任你的开发者账号，然后在手机上手动打开。"
  echo "已在 ${CHOSEN_NAME} 上启动。真机上请手动登录各账号（脚本不会传递任何账号密码）。"
else
  echo "已安装到 ${CHOSEN_NAME}（未启动）。"
fi
if [ "$PERSONAL" = 1 ]; then
  echo
  echo "【免费账号提示】描述文件 7 天后过期，到期后 App 会打不开：重新运行 scripts/run-device.sh --personal 重新安装即可。"
  echo "首次打开提示「不受信任的开发者」：设置 → 通用 → VPN 与设备管理 → 信任你的开发者账号。TestFlight 和 archive.sh 上传需要付费账号。"
fi
