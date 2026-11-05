#!/bin/bash
# 运行所有带 Tests 目录的 package 的测试。用法：test.sh [PackageName...]
source "$(dirname "$0")/_env.sh"
cd "$ROOT/Packages"
PACKAGES=("$@")
if [ ${#PACKAGES[@]} -eq 0 ]; then
  for dir in */; do [ -d "${dir}Tests" ] && PACKAGES+=("${dir%/}"); done
fi
for pkg in "${PACKAGES[@]}"; do
  echo "==> test $pkg"
  (cd "$pkg" && xcodebuild -scheme "$pkg-Package" -destination "$DESTINATION" \
    -derivedDataPath "$ROOT/.build/pkg-$pkg" CODE_SIGNING_ALLOWED=NO test -quiet)
done
echo "TEST OK"
