#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="https://api.tool.gxutech.xyz"
source "$ROOT/.secrets/account.env"
YEAR="${1:-2025}"; TERM="${2:-1}"
OUT="$ROOT/Fixtures/raw"; mkdir -p "$OUT"
JAR="$(mktemp)"; trap 'rm -f "$JAR"' EXIT

LOGIN_JSON="$(JW_USER="$JW_USER" JW_PASS="$JW_PASS" python3 - <<'PY'
import json, os
print(json.dumps({"username": os.environ["JW_USER"], "password": os.environ["JW_PASS"]}))
PY
)"
printf '%s' "$LOGIN_JSON" | curl -sS -c "$JAR" -D "$OUT/jw_login.headers.txt" -o "$OUT/jw_login.body.json" \
  -H 'Content-Type: application/json' \
  --data-binary @- "$BASE/jw/login"
grep -q JSESSIONID "$JAR" || { echo "登录失败，见 $OUT/jw_login.*" >&2; exit 1; }

fetch() {
  curl -sS -b "$JAR" -o "$OUT/$1.json" -w "$1 -> HTTP %{http_code}\n" "$BASE$2"
}
fetch schedule_personal "/jw/schedule/personal?year=$YEAR&term=$TERM"
fetch profile_startDay  "/jw/profile/startDay"
fetch exam              "/jw/exam?year=$YEAR&term=$TERM"
fetch score             "/jw/score?pageSize=100&pageNo=1&orderBy=desc&order=cjbdsj"
fetch score_usual       "/jw/score/usual?year=$YEAR&term=$TERM"
fetch selected_courses       "/jw/selected-courses"
fetch selected_courses_term  "/jw/selected-courses?year=$YEAR&term=$TERM"
fetch elective_progress      "/jw/elective-progress"
fetch evaluation             "/jw/evaluation"
fetch teachers_search        "/teachers/search?q=%E7%8E%8B&page=1"
read -r TNAME TUNIT < <(python3 - "$OUT/teachers_search.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])).get("data") or {}
items = d.get("items") or d.get("list") or (d if isinstance(d, list) else [])
first = items[0] if items else {}
print(first.get("name", ""), first.get("school") or first.get("unit") or first.get("department") or "")
PY
)
if [ -n "${TNAME:-}" ]; then
  curl -sS -b "$JAR" -G --data-urlencode "name=$TNAME" --data-urlencode "school=${TUNIT:-}" \
    -o "$OUT/teachers_profile.json" -w "teachers_profile -> HTTP %{http_code}\n" "$BASE/teachers/profile"
fi
curl -sS -b "$JAR" -X POST -H 'Content-Type: application/json' -d '{"isFull":false}' \
  -o "$OUT/profile.json" -w "profile -> HTTP %{http_code}\n" "$BASE/jw/profile"
echo "已保存到 ${OUT}（含真实数据，使用前请脱敏）"
