#!/bin/bash
# xcodegen generate 后构建 App 和 Widget（iOS 模拟器，ad-hoc 签名）。
# build.sh release：用独立的 DerivedData 从零构建 Release + 真机架构（不签名），能发现"增量构建碰巧能过、干净构建失败"的问题（上架打包前跑一次）
source "$(dirname "$0")/_env.sh"
cd "$ROOT"
xcodegen generate --quiet
if [ "${1:-}" = release ]; then
  rm -rf .build-release
  xcodebuild -project GxuToolApp.xcodeproj -scheme GxuToolApp -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath .build-release CODE_SIGNING_ALLOWED=NO build -quiet
  rm -rf .build-release
  echo "RELEASE BUILD OK"
  exit 0
fi
for scheme in GxuToolApp GxuWidget; do
  echo "==> build $scheme"
  xcodebuild -project GxuToolApp.xcodeproj -scheme "$scheme" \
    -destination "$DESTINATION" -derivedDataPath .build \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=YES build -quiet
done
echo "BUILD OK"
