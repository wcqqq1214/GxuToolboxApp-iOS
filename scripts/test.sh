#!/bin/bash
source "$(dirname "$0")/_env.sh"
cd "$ROOT/Packages"
PACKAGES=("$@")
if [ ${#PACKAGES[@]} -eq 0 ]; then
  for dir in */; do [ -d "${dir}Tests" ] && PACKAGES+=("${dir%/}"); done
fi
for pkg in "${PACKAGES[@]}"; do
  echo "==> test $pkg"
  SCHEME="$pkg-Package"
  (cd "$pkg" && xcodebuild -list 2>/dev/null | grep -qx "        $SCHEME") || SCHEME="$pkg"
  (cd "$pkg" && xcodebuild -scheme "$SCHEME" -destination "$DESTINATION" \
    -derivedDataPath "$ROOT/.build/pkg-$pkg" CODE_SIGNING_ALLOWED=NO test -quiet)
done
if [ "$#" -eq 0 ]; then
  cd "$ROOT"
  echo "==> test GxuToolAppTests"
  xcodegen generate --quiet
  xcodebuild -project GxuToolApp.xcodeproj -scheme GxuToolApp -destination "$DESTINATION" \
    -derivedDataPath .build -only-testing:GxuToolAppTests CODE_SIGNING_ALLOWED=NO test -quiet
  echo "==> test capture-fixtures"
  python3 scripts/tests/test_capture_fixtures.py
fi
echo "TEST OK"
