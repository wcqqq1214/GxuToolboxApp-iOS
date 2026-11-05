#!/bin/bash
# 登录后端并保存各接口原始响应到 Fixtures/raw/（已 gitignore，内含真实数据，禁止提交）。
# 账号放在 .secrets/account.env：JW_USER=... JW_PASS=...
# 用法：capture-fixtures.sh [year] [term]   （term 为逻辑学期 1/2，默认 2025 / 1）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="http://api.tool.gxutech.xyz"
source "$ROOT/.secrets/account.env"
YEAR="${1:-2025}"; TERM="${2:-1}"
OUT="$ROOT/Fixtures/raw"; mkdir -p "$OUT"
JAR="$(mktemp)"; trap 'rm -f "$JAR"' EXIT

curl -sS -c "$JAR" -D "$OUT/jw_login.headers.txt" -o "$OUT/jw_login.body.json" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$JW_USER\",\"password\":\"$JW_PASS\"}" "$BASE/jw/login"
grep -q JSESSIONID "$JAR" || { echo "登录失败，见 $OUT/jw_login.*" >&2; exit 1; }

fetch() { # name path
  curl -sS -b "$JAR" -o "$OUT/$1.json" -w "$1 -> HTTP %{http_code}\n" "$BASE$2"
}
fetch schedule_personal "/jw/schedule/personal?year=$YEAR&term=$TERM"
fetch profile_startDay  "/jw/profile/startDay"
fetch exam              "/jw/exam?year=$YEAR&term=$TERM"
fetch score             "/jw/score?pageSize=100&pageNo=1&orderBy=desc&order=cjbdsj"
fetch score_usual       "/jw/score/usual?year=$YEAR&term=$TERM"
curl -sS -b "$JAR" -X POST -H 'Content-Type: application/json' -d '{"isFull":false}' \
  -o "$OUT/profile.json" -w "profile -> HTTP %{http_code}\n" "$BASE/jw/profile"
echo "已保存到 $OUT（含真实数据，使用前请脱敏）"
