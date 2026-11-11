#!/bin/bash
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
