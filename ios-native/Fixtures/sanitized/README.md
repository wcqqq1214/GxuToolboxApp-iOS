# 脱敏 Fixture

由 `scripts/sanitize-fixtures.py` 从 `Fixtures/raw/`（本地真实响应，不入库）生成，可以放心提交和在测试里使用。
结构、字段名、值的类型与真实响应一致；姓名、学号、身份证、班级名、教师姓名、QQ 群号、成绩记录 ID 已替换成假数据。
课程名、教室、学分、成绩数值、时间等**未改动**（不指向个人身份）。需要更新时：`scripts/capture-fixtures.sh && scripts/sanitize-fixtures.py`。

所有 `/jw/*` 响应形如 `{code, message, data}`，可直接用 `DataEnvelope` 解码（`getData` 已封装）。

| 文件 | 接口 | 抓取参数 | 备注 |
|---|---|---|---|
| `schedule-personal.json` | `GET /jw/schedule/personal` | `year=2025&term=1` | `data = {practiceList, theoryList, personalInfo}`。practiceList 的 `courseName` 里内嵌了教师名和周次 |
| `profile-startDay.json` | `GET /jw/profile/startDay` | 无 | `day` 是 UTC 零点 ISO 串；没有 `is_current` |
| `exam.json` | `GET /jw/exam` | `year=2025&term=1` | `time` 形如 `2026-01-23(09:00-11:00)`；结果里还混有往届缓考/补考 |
| `score.json` | `GET /jw/score` | `pageSize=100&pageNo=1&orderBy=desc&order=cjbdsj` | `data = {totalCount, totalPage, currentPage, items}`；这是第 1 页（totalCount=117，items 有 100 条），同时有 snake_case 和 camelCase 两套字段；`term=0` 表示未分学期 |
| `score-usual.json` | `GET /jw/score/usual` | `year=2025&term=1`（未带课程 id） | `data` 为空数组；带 `id` 的真实响应尚未抓取 |
| `profile.json` | `POST /jw/profile` | body `{"isFull":false}` | **返回 HTTP 201**；`grade`（入学年份）、`study_years` 都是**字符串** |
| `selected-courses.json` | `GET /jw/selected-courses` | 无参数 | `data = {currentPage, totalPage, totalCount, items}`，一页返回全部（135 门，含历年）。条目字段：`classId, courseId, courseName, type(理论/实验/实践/实习), selectionType(主修课程/通识选修课/重修课程/体育分项…), classification(公共课/专业课), belongTo, system, teacher, teacherId, location, credit, year, term`（`credit/year/term` 是数字，其余是字符串）。`teacher` / `teacherId` 可能是逗号分隔的多人；`location` 多个教室用 `;` 分隔，可能为空串；`belongTo` 可能为空串。教师姓名、工号已替换（工号 `000000` 是网络课程占位，保留） |
| `selected-courses-term.json` | `GET /jw/selected-courses` | `year=2025&term=1` | 同上，只含该学期（17 门） |
| `jw-login-success.json` | `POST /jw/login` | 正确账号 | **HTTP 201**，响应头带 `Set-Cookie: JSESSIONID, route`（头未保存） |
| `jw-login-failure.json` | `POST /jw/login` | 错误密码 | HTTP 401，手写 |
| `session-expired.json` | 任意需登录接口 | Cookie 无效 | HTTP 401，手写 |
