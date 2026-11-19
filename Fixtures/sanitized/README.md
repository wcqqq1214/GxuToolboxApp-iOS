# 脱敏接口样本（Fixtures）

这批 JSON 文件由 `scripts/sanitize-fixtures.py` 处理 `Fixtures/raw/` 下的本地真实抓包生成（原始抓包不提交进仓库），供日常开发与单元测试使用。响应结构、字段名和数据类型都与真实接口一致，姓名、学号、身份证号、班级名称、教师姓名、QQ 群号以及成绩记录 ID 已全部替换为假数据；课程名、教室、学分、分数、时间等不含个人身份的字段保留原样。

需要更新样本时，先把教务账号 `JW_USER` 和 `JW_PASS` 写进本地 `.secrets/account.env`，再依次执行：

1. `scripts/capture-fixtures.sh [year] [term]`：抓取原始响应（默认 `2025` 学年第 `1` 学期，`term` 仅支持 `1` 或 `2`）。脚本通过 `curl` 登录教务后端，排查「无法获取初始登录cookie」问题时也可以对照它的 User-Agent。
2. `scripts/sanitize-fixtures.py`：生成脱敏后的 JSON 文件。
3. `python3 scripts/sync-fixtures.py --write`：把更新后的样本同步到各个 Package 测试目录下的同名副本（CI 会检查副本是否和本目录一致，不要直接手改测试目录里的副本）。

所有 `/jw/*` 接口都返回 `{code, message, data}` 结构，可直接用 `DataEnvelope` 解码（`getData` 已封装好）。

| 文件 | 接口 | 抓取参数 | 字段与脱敏说明 |
|---|---|---|---|
| `schedule-personal.json` | `GET /jw/schedule/personal` | `year=2025&term=1` | `data = {practiceList, theoryList, personalInfo}`，其中 `practiceList` 的 `courseName` 里拼入了教师名和周次 |
| `profile-startDay.json` | `GET /jw/profile/startDay` | 无 | `day` 是 UTC 零点的 ISO 字符串，不含 `is_current` 字段 |
| `exam.json` | `GET /jw/exam` | `year=2025&term=1` | `time` 格式形如 `2026-01-23(09:00-11:00)`，列表里还会混有往届缓考或补考记录 |
| `score.json` | `GET /jw/score` | `pageSize=100&pageNo=1&orderBy=desc&order=cjbdsj` | `data = {totalCount, totalPage, currentPage, items}`。这里是第 1 页（共 117 条、本页 100 条），字段同时包含 snake_case 和 camelCase；`term=0` 代表未标明学期 |
| `score-usual.json` | `GET /jw/score/usual` | `year=2025&term=1`（未带课程 ID） | `data` 为空数组，带课程 `id` 的真实响应尚未抓取 |
| `profile.json` | `POST /jw/profile` | 请求体 `{"isFull":false}` | **返回 HTTP 201**；`grade`（入学年份）和 `study_years` 都是**字符串** |
| `selected-courses.json` | `GET /jw/selected-courses` | 无 | `data = {currentPage, totalPage, totalCount, items}`，一页返回历年全部 135 门。字段包括 `classId, courseId, courseName, type(理论/实验/实践/实习), selectionType(主修课程/通识选修课/重修课程/体育分项…), classification(公共课/专业课), belongTo, system, teacher, teacherId, location, credit, year, term`（仅 `credit/year/term` 为数字，其余是字符串）。`teacher` / `teacherId` 可能是逗号分隔的多位教师；`location` 多个教室用 `;` 分隔，且和 `belongTo` 一样可能为空串。教师姓名与工号已替换（网络课程占位工号 `000000` 保留） |
| `selected-courses-term.json` | `GET /jw/selected-courses` | `year=2025&term=1` | 结构同上，只包含单学期 17 门课程 |
| `teachers-search.json` | `GET /teachers/search` | `q=王&page=1`（无需登录） | `data = {pages, total, list: [{id, name, picUrl, unit}]}`（共 17 页 194 条，本页 12 条）。姓名换为「王测一…」，`id` 换为等长假值，`picUrl` 换为 `example.invalid` |
| `teachers-profile.json` | `GET /teachers/profile` | `name=<搜索首条姓名>&school=<对应 unit>`（无需登录） | `data = {baseInfo, academicProfile}`。姓名、头像、联系方式、地址和工号已替换；个人简介、主讲课程、研究方向、学术兼职和成果等自由文本替换为同结构示例文字（保留多行字段行数）；职称、学历、导师类别和学科门类保持原样。真实接口中的空字段返回 `""` 而非 `null` |
| `elective-progress.json` | `GET /jw/elective-progress` | 无 | `data = {studentId, computedAt, grade, ruleId, ruleVersion, ruleName, complete, stats{totalCredits, offlineCredits, modules{lead, entrepreneurship, art, asean, ethnic, ocean:{credits, courseCount}}}, requirements[{key,label,actual,required,operator,unit,passed}], remainingRequired, courses[{courseId, courseName, classIds, locations, teachers, modules, online, credit, score, status, counted, countedCredits, excludedReason, attempts[…]}], issues[{code,courseId,classId,message}], isQualified}`。`studentId` 已替换成假学号（RN 端校验它须与当前登录账号一致）；课程和教学班 ID 换为等长假十六进制，教师换为「测试教师N」；该账号样本中 `passed` 与 `isQualified` 为 `null`，`issues` 含一条 `missing_identity`，学分、课名与规则保留原样 |
| `jw-login-success.json` | `POST /jw/login` | 正确账号 | **HTTP 201**，响应头含 `Set-Cookie: JSESSIONID, route`（响应头未落盘） |
| `jw-login-failure.json` | `POST /jw/login` | 错误密码 | HTTP 401，手写构造 |
| `session-expired.json` | 任意需登录接口 | Cookie 无效 | HTTP 401，手写构造 |

**关于缺失的 `GET /jw/evaluation`（期末评教列表）：** 2026-11-06 请求真实后端返回 HTTP 404（`{"code":404,"message":"Cannot GET /jw/evaluation","data":null}`），说明服务端尚未上线这个路由，因此这里没有样本也不手写伪造。RN 上游在兜底时会直连教务 `/xspjgl/xspj_cxXspjIndex.html`，需要直连会话，这里暂未抓取。
