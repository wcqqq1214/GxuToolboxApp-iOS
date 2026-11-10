#!/bin/bash
# 打包并上传 TestFlight。
# 用法：
#   scripts/archive.sh --check           只检查前置条件（Team ID、隐私清单、版本号、工具），不构建
#   scripts/archive.sh                   archive → 导出 .ipa 到 build/export/（不上传）
#   scripts/archive.sh --upload          archive → 直接上传到 App Store Connect（TestFlight）
# 环境变量 / 配置：
#   DEVELOPMENT_TEAM    Apple Developer Team ID（10 位大写字母数字）。也可以在 project.yml 的 DEVELOPMENT_TEAM 填写，
#                       或写到 .secrets/archive.env（已 gitignore）
#   BUILD_NUMBER        覆盖构建号（CURRENT_PROJECT_VERSION），默认用 project.yml 里的值；每次上传必须递增
#   上传认证：默认使用 Xcode 里登录的 Apple ID；也可以用 App Store Connect API Key：
#   ASC_KEY_PATH（.p8 文件）、ASC_KEY_ID、ASC_ISSUER_ID
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[ -f .secrets/archive.env ] && source .secrets/archive.env

# xcode-select 指向 CommandLineTools 时，改用 /Applications/Xcode.app（和 _env.sh 一致）
if ! xcrun --find xcodebuild >/dev/null 2>&1 || [[ "$(xcode-select -p 2>/dev/null)" == *CommandLineTools* ]]; then
  for app in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    if [ -d "$app" ]; then export DEVELOPER_DIR="$app/Contents/Developer"; break; fi
  done
fi

MODE=export; CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --upload) MODE=upload ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "未知参数：${arg}（见 --help）" >&2; exit 2 ;;
  esac
done

errors=()
fail() { errors+=("$1"); }

# 1. 工具
command -v xcodegen >/dev/null || fail "找不到 xcodegen（brew install xcodegen）"
xcrun --find xcodebuild >/dev/null 2>&1 || fail "找不到 xcodebuild：请安装 Xcode"

# 2. Team ID：环境变量 > project.yml
PROJECT_TEAM="$(sed -n 's/^ *DEVELOPMENT_TEAM: *"\{0,1\}\([^"]*\)"\{0,1\} *\(#.*\)\{0,1\}$/\1/p' project.yml | head -1)"
TEAM="${DEVELOPMENT_TEAM:-$PROJECT_TEAM}"
if [ -z "$TEAM" ] || [ "$TEAM" = "YOUR_TEAM_ID" ]; then
  fail "还没有填写 Apple Developer Team ID。请设置环境变量 DEVELOPMENT_TEAM=<10 位 Team ID>，或写进 .secrets/archive.env（DEVELOPMENT_TEAM=...），或把 project.yml 里的 DEVELOPMENT_TEAM 占位符 YOUR_TEAM_ID 换成真实值（Team ID 在 developer.apple.com → Membership 里查看）"
elif ! [[ "$TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
  fail "Team ID 格式不对：应为 10 位大写字母或数字，现在是「${TEAM}」"
fi

# 3. 版本号
VERSION="$(sed -n 's/^ *MARKETING_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}.*/\1/p' project.yml | head -1)"
BUILD="${BUILD_NUMBER:-$(sed -n 's/^ *CURRENT_PROJECT_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\}.*/\1/p' project.yml | head -1)}"
[ -n "$VERSION" ] || fail "project.yml 里找不到 MARKETING_VERSION"
[[ "$BUILD" =~ ^[0-9]+$ ]] || fail "构建号必须是整数：现在是「${BUILD:-空}」"

# 4. 隐私清单必须存在且格式正确（App 和小组件各一份）
for f in App/Resources/PrivacyInfo.xcprivacy Widget/PrivacyInfo.xcprivacy; do
  if [ ! -f "$f" ]; then fail "缺少隐私清单 $f"
  elif ! plutil -lint "$f" >/dev/null 2>&1; then fail "隐私清单格式错误：${f}（运行 plutil -lint $f 查看）"; fi
done

# 5. 上传认证（只在 --upload 时检查）
AUTH_ARGS=()
if [ "$MODE" = upload ] && [ -n "${ASC_KEY_PATH:-}" ]; then
  [ -f "$ASC_KEY_PATH" ] || fail "ASC_KEY_PATH 指向的文件不存在：$ASC_KEY_PATH"
  [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] || fail "使用 API Key 上传需要同时设置 ASC_KEY_ID 和 ASC_ISSUER_ID"
  AUTH_ARGS=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "${ASC_KEY_ID:-}" -authenticationKeyIssuerID "${ASC_ISSUER_ID:-}")
fi

if [ ${#errors[@]} -gt 0 ]; then
  echo "打包前检查未通过：" >&2
  for e in "${errors[@]}"; do echo "  ✗ $e" >&2; done
  exit 1
fi
echo "前置检查通过：Team ${TEAM}，版本 $VERSION ($BUILD)，模式 $MODE"
[ "$CHECK_ONLY" = 1 ] && exit 0

# 6. 构建
ARCHIVE="$ROOT/build/GxuToolApp.xcarchive"
EXPORT_DIR="$ROOT/build/export"
rm -rf "$ARCHIVE" "$EXPORT_DIR"; mkdir -p "$ROOT/build"
xcodegen generate --quiet
xcodebuild -project GxuToolApp.xcodeproj -scheme GxuToolApp -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic CURRENT_PROJECT_VERSION="$BUILD" \
  -allowProvisioningUpdates "${AUTH_ARGS[@]}" archive -quiet

# 7. 导出 / 上传
OPTIONS="$ROOT/build/ExportOptions.plist"
cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>destination</key><string>$([ "$MODE" = upload ] && echo upload || echo export)</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTIONS" -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates "${AUTH_ARGS[@]}"

if [ "$MODE" = upload ]; then
  echo "已上传到 App Store Connect：版本 $VERSION ($BUILD)。几分钟后在 TestFlight 里处理完成。"
else
  echo "已导出：${EXPORT_DIR}（未上传；要直接上传请加 --upload）"
fi
