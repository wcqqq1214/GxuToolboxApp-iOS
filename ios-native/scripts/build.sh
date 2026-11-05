#!/bin/bash
# xcodegen generate 后构建 App 和 Widget（iOS 模拟器，不签名）
source "$(dirname "$0")/_env.sh"
cd "$ROOT"
xcodegen generate --quiet
for scheme in GxuToolApp GxuWidget; do
  echo "==> build $scheme"
  xcodebuild -project GxuToolApp.xcodeproj -scheme "$scheme" \
    -destination "$DESTINATION" -derivedDataPath .build \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES build -quiet
done
echo "BUILD OK"
