#!/usr/bin/env python3
"""把 Fixtures/raw/ 里的真实响应脱敏后写入 Fixtures/sanitized/（可入库）。

替换：姓名、学号、身份证、班级名、教师姓名、QQ 群号、成绩记录 ID。结构和值的类型不变。
脱敏后会用原始数据里的敏感值再扫描一遍输出，发现残留就报错退出。
用法：scripts/sanitize-fixtures.py
"""
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW, OUT = ROOT / "Fixtures/raw", ROOT / "Fixtures/sanitized"

FAKE_NAME, FAKE_ID, FAKE_ID_CARD, FAKE_CLASS = "测试同学", "2200000001", "450000200001010019", "示例专业221"


def load(name):
    return json.loads((RAW / name).read_text(encoding="utf-8"))


profile = load("profile.json")["data"]
schedule = load("schedule_personal.json")
info = schedule["data"].get("personalInfo", {})

sensitive_scalars = {
    v for v in [profile.get("student_id"), profile.get("name"), profile.get("id_card"),
                profile.get("class_name"), info.get("id"), info.get("name"), info.get("className")] if v
}

teacher_keys = {"teacher", "teacher_name", "teacherName"}
GENERIC_TEACHERS = {"无"}   # 不是具体的人，保留原样（"网络教师"仍会被编号，和已发布的 fixture 保持一致）
GENERIC_TEACHER_IDS = {"000000"}       # 占位工号（网络课程等），保留原样
teachers = set()
teachers_legacy = set()               # 最早那 5 个文件里出现的教师：编号保持稳定，不因新增文件而改变已发布 fixture
teacher_ids = set()


def collect(x):
    if isinstance(x, dict):
        for k, v in x.items():
            if k in teacher_keys and isinstance(v, str):
                teachers.update(t.strip() for t in re.split(r"[,;，；]", v) if t.strip() and t.strip() not in GENERIC_TEACHERS)
            if k == "teacherId" and isinstance(v, str):
                teacher_ids.update(t.strip() for t in v.split(",") if t.strip() and t.strip() not in GENERIC_TEACHER_IDS)
            collect(v)
    elif isinstance(x, list):
        for v in x:
            collect(v)


qq_groups = set()
for f in ["schedule_personal.json", "exam.json", "score.json", "profile_startDay.json", "score_usual.json",
          "selected_courses.json", "selected_courses_term.json"]:
    before = set(teachers)
    collect(load(f))
    if not f.startswith("selected_courses"):
        teachers_legacy.update(teachers - before)
for item in schedule["data"].get("theoryList", []):
    if item.get("qqGroup"):
        qq_groups.add(item["qqGroup"])

ordered_teachers = sorted(teachers_legacy) + sorted(teachers - teachers_legacy)
teacher_map = {name: f"教师{i + 1:02d}" for i, name in enumerate(ordered_teachers)}
teacher_id_map = {t: str(90000001 + i) for i, t in enumerate(sorted(teacher_ids))}   # 教师工号 -> 假工号（8 位，格式不变）
qq_map = {g: str(100000001 + i) for i, g in enumerate(sorted(qq_groups))}
# 长名字优先，避免短名字是长名字子串时被误替换
teacher_pattern = re.compile("|".join(re.escape(n) for n in sorted(teacher_map, key=len, reverse=True))) if teacher_map else None


def fake_hex(value):
    return hashlib.sha1(value.encode()).hexdigest().upper()[: len(value)]


def scrub(x, key=None):
    if isinstance(x, dict):
        return {k: scrub(v, k) for k, v in x.items()}
    if isinstance(x, list):
        return [scrub(v, key) for v in x]
    if not isinstance(x, str):
        return x
    if key in ("student_id", "id") and x in sensitive_scalars:
        return FAKE_ID
    if key == "name" and x in sensitive_scalars:
        return FAKE_NAME
    if key == "id_card":
        return FAKE_ID_CARD
    if key in ("class_name", "className"):
        return FAKE_CLASS
    if key == "teacherId":
        return ",".join(teacher_id_map.get(t.strip(), t) for t in x.split(","))
    if key == "qqGroup":
        return qq_map.get(x, x)
    if key == "id" and re.fullmatch(r"[0-9A-F]{32}", x):  # 成绩记录 ID
        return fake_hex(x)
    if teacher_pattern and (key in teacher_keys or key == "courseName"):
        return teacher_pattern.sub(lambda m: teacher_map[m.group(0)], x)
    return x


FILES = {  # raw -> sanitized
    "schedule_personal.json": "schedule-personal.json",
    "profile_startDay.json": "profile-startDay.json",
    "exam.json": "exam.json",
    "score.json": "score.json",
    "score_usual.json": "score-usual.json",
    "profile.json": "profile.json",
    "selected_courses.json": "selected-courses.json",
    "selected_courses_term.json": "selected-courses-term.json",
    "jw_login.body.json": "jw-login-success.json",
}
OUT.mkdir(parents=True, exist_ok=True)
for raw_name, out_name in FILES.items():
    path = RAW / raw_name
    if not path.exists():
        print(f"跳过（不存在）：{raw_name}")
        continue
    cleaned = scrub(json.loads(path.read_text(encoding="utf-8")))
    (OUT / out_name).write_text(json.dumps(cleaned, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# 手写的错误响应（后端真实格式，不含个人信息）
(OUT / "jw-login-failure.json").write_text(
    json.dumps({"code": 401, "message": "账号或密码错误，登录失败", "data": None}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(OUT / "session-expired.json").write_text(
    json.dumps({"code": 401, "message": "登录态过期，请重新登录", "data": None}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# 残留检查
needles = set(sensitive_scalars) | set(teacher_map) | set(teacher_ids) | set(qq_map)
leaks = []
for f in OUT.glob("*.json"):
    text = f.read_text(encoding="utf-8")
    leaks += [(f.name, n) for n in needles if n in text]
if leaks:
    print("发现残留敏感数据：", leaks, file=sys.stderr)
    sys.exit(1)
print(f"已写入 {OUT}（{len(list(OUT.glob('*.json')))} 个文件），残留检查通过")
