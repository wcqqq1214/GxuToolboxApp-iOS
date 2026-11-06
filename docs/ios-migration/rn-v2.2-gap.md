# RN v2.2 与 iOS 的差距（对齐基准：`origin/v2.2` @ `c7c11bc3`）

用户决定（2026-11-06）：**iOS 对齐最新的 RN 分支**，基准固定为 `c7c11bc3`（比 `main` 多 92 个提交、195 个文件、+20847/−3552 行）。读 RN 代码用 `git show c7c11bc3:<路径>`、`git diff main c7c11bc3 -- <路径>`（所有 worktree 共享这些 ref）。RN 决定功能和数据，界面按 PLAN §6（教师查询页除外，先跟 RN 结构）。绩点重修逻辑不在 RN 里，按 `[gpa-retake]`，不要回退。

本文件由 A 写，B、C 按它干活。路由核对时间 2026-11-06，**只用只读请求**（未登录的探测，加一次后端登录后的两个只读 GET），不向线上写任何数据。

## 1. 后端路由核对（v2.2 用到的全部后端路径 vs `main`）

| 路由 | v2.2 | 后端真实情况（实测） | iOS 现状 | 负责人 |
|---|---|---|---|---|
| `GET /jw/emptyClassroom` | **新增** | ✅ 存在。参数（数组用重复键，`indexes: null`）：`weekDay[]`(1–7)、`weekList[]`、`timeList[]`(节次 1–13)、`year`、`term`(逻辑学期 1/2)、`pageNum`、`pageSize`。**`pageSize=10000` 一次返回一个节次的全部空闲教室**（实测 1710 条，`totalPage=1`）。响应 `data = {totalPage,totalCount,currentPage,items:[{classroomName,placeType,seatCount,seatCountForExam,building,owner,user,allowToUse,currentPage}]}`，`seatCount` 等是**字符串**，`building` 要 trim；`items` 是「该节次空闲」的教室 | 没有 | B |
| `GET /jw/elective-progress` | **新增** | ✅ 存在，需教务会话。`data = {studentId,computedAt,grade,ruleId,ruleVersion,ruleName,complete,stats:{totalCredits,offlineCredits,modules:{lead,entrepreneurship,art,asean,ethnic,ocean:{credits,courseCount}}},requirements:[{key,label,actual,required,operator,unit,passed}],remainingRequired…}`。RN 要求 `data.studentId` 必须等于当前账号，否则报错、不写缓存 | 没有（iOS 现在用 `/jw/score` 本地算） | C |
| `GET /attendance/v2/captcha` | **新增（替换 `/attendance/captcha`）** | ✅ 存在，无需登录。响应 `data = {imageUrl:"data:image/jpeg;base64…", challengeToken:str(43), text:str(4)}`——**后端把验证码文字 `text` 一起返回了**（RN 的「happy path」应该是自动填充） | iOS 用旧的 `/attendance/captcha`（`image` + `ticket`） | **A**（认证）、C（考勤界面） |
| `POST /attendance/v2/login` | **新增（替换 `/attendance/login`）** | ✅ 存在（空体返回字段校验信息）。body `{username,password,captchaCode,ticket}`（`ticket` = captcha 的 `challengeToken`），返回 `data = {token,calendarId,userId}`（`AttendanceSession`）。**完整登录没有验证过**（需要考勤账号） | iOS 用旧登录 | **A** |
| `GET /attendance/*` 数据接口 | 路径不变（`Authorization: Token`），**响应壳变了**：`authGet` 返回 `res.data`（单层 `{code,…}`），`getMenuData` / `testToken` 判 `code === 200`（v1 是内层 `600`）；类型来自 `@gxutool/adapters/attendance`（`RecordPage`、`Schedule`） | 旧路径仍存在；v2 数据的真实形状**未验证**（需要考勤 token） | iOS 按 v1 双层壳 + 600 | **A**（`AttendanceSession` / 请求头）、C（数据模型）→ 后续测试 |
| `/attendance/captcha`、`/attendance/login` | RN v2.2 **已不再调用** | 后端旧路由还在（`/attendance/captcha` 实测 200） | iOS 还在用 | 迁到 v2 后可删 |
| `GET /jw/exam`、`/jw/score`、`/jw/score/usual`、`/jw/schedule/*`、`/jw/profile*`、`/jw/selected-courses`、`/teachers/*` | 不变；`/jw/exam` 的 `term` 只接受逻辑码 1/2（RN 在边界统一把旧码 3/12 转成 1/2） | ✅ | 已对齐（iOS 一直用逻辑学期） | — |

## 2. 之前记录的「RN 缺口」在 v2.2 的变化（逐个重新核对）

| 缺口 | v2.2 有没有变化 | 实测 | 结论 |
|---|---|---|---|
| 调课信息（`reschedulingNews`） | **没有**（RN 仍直连教务，v2.2 没有新增后端路由；工具箱入口也还在） | `GET /jw/schedule/adjust`、`/jw/timeShift`、`/jw/rescheduling` 等猜测路径全是 404 | **保持隐藏，等后端** |
| 选课课程列表（`courseSelectionList`） | **没有**（仍直连教务；v2.2 工具箱里仍有这一项） | `/jw/courseSelection`、`/jw/course-selection` 404 | **保持隐藏，等后端** |
| 期末学生评价 | **没有**（RN v2.2 仍调 `GET /jw/evaluation`，保留直连教务兜底） | `GET /jw/evaluation` 仍然 404 `Cannot GET` | **保持「即将上线」，等后端部署** |
| 我的反馈 | **没有**（仍 `GET /feedback/{userId}`） | 仍然 401「看板：未登录或登录已过期」 | **保持隐藏（开关默认关闭）** |
| 工具箱：空闲教室 | **新增**，`ToolboxIndex` 加了「空闲教室」（`navigation: emptyClassroom`，缓存管理 `emptyClassroomCache`） | 后端路由真实存在 | **iOS 要加回**（我之前说「RN 没有空教室」是查了旧分支，错的） |
| 工具箱：「课表」 | 改名「**个人课表**」 | — | B 改名 |
| 工具箱：考勤 | 路由 `AttendanceInfoQueryScreen` → `AttendanceScreen`（`features/attendance`，重构） | — | C |

## 3. 逐 feature 差距

### A（认证、账号、设置、文件）
| 项 | v2.2 做了什么 | iOS 差距 | 做法 |
|---|---|---|---|
| `src/core/auth/Jw`：`6c59a755 收拢后端登录并清理旧网关`、`c59ebe5a fix(教务账号)：同步查询账号与认证状态` | 教务登录只走后端，删掉本地 / 远程网关切换；账号页同步查询账号与认证状态 | **已一致**：iOS 一直只走后端；账号状态已按 `[auth-state-fix]` 统一为一个来源 | 无需改 |
| `1172edb0 提示APP仅本科生可用` | 教务账号页加提示卡片：「全校本科生均可用 / 研究生还请移步至GXU研课表(gxu.app)」 | 没有 | A：教务账号页加这句提示（文案原样） |
| `4bc024ed 微调教务登录页样式` | 登录页样式 | 按 PLAN §6 自己设计，不照搬 | 不做 |
| `src/core/auth/attendance`（`43f2ef10 适配考勤V2接口`、`eb91acde 重构考勤系统体验`） | v2 captcha / login，`AttendanceSession{token,calendarId,userId}`，token 存本地 | 见上表 | A：`AttendanceSession` 迁到 v2（captcha 的 `text` 可用于自动填充）；账号页配合；完整登录要考勤账号，真实验证标「后续测试」 |
| `src/features/documents`：`331e3aa8 修复退出文件系统登录的按钮的错误逻辑`（`LoginDialog` 一行） | 「退出登录」按钮的 disabled 条件修正 | iOS 的退出按钮在已登录时显示、未登录时不显示，没有这个问题 | 已一致 |
| `src/js/jw`、`src/class/jw`、`src/js/nextCourses.ts`、`src/js/mgr` 的小改动 | 清理死代码（教务直连考试接口等）、`dc181ca2 完整化体育课上课地址字段`（已在 iOS：`44c99e8`/B） | — | 无需改 |
| `src/core/schema.ts`、`src/core/db.ts`、`drizzle/` | RN 本地 SQLite（空教室缓存表等） | iOS 用 GRDB，自己设计表 | 不做（B 自己建表） |

### B（课表 / 校园）
| 项 | v2.2 做了什么 | 备注 |
|---|---|---|
| **空闲教室**（`src/features/emptyClassroom`，39 个文件、8000+ 行，含测试） | 按时间查询（周 / 星期 / 节次范围）、结果分页（每页 40 间）、楼栋和楼层分组的教室选择器（`RoomPickerSheet`）、教室搜索（懒加载楼栋）、筛选、节次、**时段高亮**、周缓存管理（`EmptyClassroomCacheScreen`：1–20 周、开始 / 取消、**两次开始至少间隔 60 秒**、缓存占用与耗时提示、按行展示每周状态）。数据：**并发请求单日 13 个节次**（`timeList=[n]`），`pageSize=10000`，兼容后端仍分页（最多 10 页）；401 时共享一次重登；缓存按「教室 × 周 × 星期」压缩存周记录；教室维表（`building`+`classroomName` 为键）+ 空闲节次表。**iOS 先做按时间查询 + 缓存管理的最小闭环，缓存用 GRDB（按 studentId 隔离只在需要时）** | 路由和响应形状见上表；`Fixtures` 里有一份真实空教室响应（见 A 的公告），B 需要时让我脱敏发布 |
| 大课表接入实验课（`83a701c2`、`f8c16621`、`f4a06094`、`88bb7de8`：教学周和节次编辑面板、本地存储、按教学周展开）并整合假期和考勤图层 | iOS 现在课表页不显示实验课 | B；实验课数据来自 A 的 PEC（`UnifiedAuthSession.loginPEC`），真实验证要统一认证账号 + 校园网 → 后续测试 |
| 跨数据源重叠块并排展示（`7bcfcf43`） | 课程 / 考试 / 日程 / 实验课重叠时并排 | B |
| 课表底栏考试信息卡（`7e65e892`）、课程信息栏重做（`a8ba580e`） | | B（iOS 已有首页「下一件事」；课程详情 sheet 对照） |
| 按账号和学期隔离的查询钩子（`6d549388`）、开学日期同步缓存（`554de77b`，默认开学日 `1fff401b` 改为 26.9.7） | | B 核对 iOS 已有的缓存隔离是否等价 |
| `getWeekOfDate` 统一教学周口径（`9bd987d9`、`f6883c2c`、`62d784bf`、`73d2d49d`）、补课日保留当天项目（`afd91703`）、调课按被补日的星期传参（`563b1ff6`）、节假日 NextEvent 表现（`1376d745`）、日程编辑修复（`e4bbd18b`） | 周数计算的口径修正 | B（逻辑 + 单测对照） |
| 课表分享显式传入数据（`c548f456`）、日期引用修复（`00fe09e1`） | | B 对照 |
| 工具箱：`ToolboxIndex.tsx` v2.2（「课表」→「个人课表」、加回「空闲教室」） | 仍由 B 改 `ToolboxCatalog` | B |
| **第 9、10 节合并行** | 用户截图显示「9-10节」；v2.2 实际做法需要对照 `TimeSchedule` 文档和渲染代码 | B 核对后按 RN 对齐显示文字 |
| 班级课表（`classCourseSchedule`）相关差异 | C 的对照结果里属于 B 的部分写进 B 的请求区 | — |

### C（考试 / 选课 / 考勤 / 教师）
| 项 | v2.2 做了什么 | 备注 |
|---|---|---|
| **考勤重构**（`src/features/attendance`，8 个文件，`AttendanceScreen`） | v2 登录（`A` 负责认证）、`getMenuData` / `testToken` 判 `code === 200`、数据类型来自 adapters（`RecordPage`、`Schedule`）、「happy path」体验 | 数据形状要看 `docs` 里的 adapters 类型或真实响应（需要考勤账号）→ 后续测试；A 的 v2 认证交付后在 C 的请求区通知 |
| **校选课查漏**（`src/features/electiveStrategy`，11 个文件 +1000 行）：`8b158170 改用后端结果并保留旧逻辑` | 正式入口转到 `ElectiveProgressScreen`，通过 `useElectiveProgress` 请求 **`GET /jw/elective-progress`**（见上表）；校验 `studentId`；**保留旧的本地算法**作为参考 / 回退 | 路由真实存在、形状已确认；C 用它替换 iOS 的本地计算（保留现有按年级规则的逻辑，不删）；创业学分与 RN 保持一致（PLAN §7） |
| **教师查询**（`src/features/teachersInfo`） | 类型迁到 `@gxutool/adapters`（`TeacherInfoList`、`TeacherInfoDetail`），多处 import 路径改动；**逻辑变化很小** | **上一轮对照的是旧基准，重新对照 v2.2**（教师查询页先跟 RN 结构） |
| **考试**（`src/features/examInfo`）：`d277943f 考试查询接口契约文档`、`4f5d5543 考试接口按后端契约转换学期码`、`StoredExam`（缓存只存纯数据，去掉运行时的 date / status） | `/jw/exam` 只接受 1/2，边界统一转换 | iOS 一直用逻辑学期，已一致；对照契约文档里的字段、S0 核查基线 |
| `src/features/widget`（4 行，`widgetScheduleData.ts`） | 随课表考试数据类型调整 | C 对照 |
| 绩点（`examScore`） | v2.2 没有变化 | 保持 `[gpa-retake]` 的规则 |

## 6. 后端待办（iOS 不绕过，只记录）

- **`/jw/elective-progress` 小学期学期映射与 `/jw/score` 不一致**：同一门《海洋与人类文明》在 elective-progress 的 `attempts` 里是 `year=2022, term=3, score=null, status=review`，`issues` 有 `missing_identity`（"课程标识或学年学期缺失"），而 `/jw/score` 里是 `term=0, score=88, credit=1`。后端应把小学期统一映射（score 的 0 ↔ progress 的 3）并按成绩匹配，这样就不会出现 `review`。iOS 端临时按"课程名 + 学分（attempt.credit）+ 学年 + 学期（3↔0）且唯一"用成绩记录核对（`ElectiveReviewResolver`），后端修好后这段会自然不再触发。（2026-11-07，C）

## 4. 与 iOS 无关 / 不做
CI 与 OTA 流水线（`.gitlab-ci.yml`、`scripts/`、`plan/`、`docs/` 里的发布文档）、RN 的 `drizzle/` 迁移与 `test.ts`、`TestPage`、`un-ui` 组件库改动、`react-native` 依赖锁文件。

## 5. 顺序和依赖
1. A：本文件 + PLAN 更新 + `[gap-v22] A`（本次）→ A 自己的部分（本科生提示、考勤 v2 认证）。
2. B：空闲教室（路由已确认，可直接做）和工具箱；课表变化逐项对照。
3. C：校选课查漏接 `/jw/elective-progress`；教师查询、考试、widget 对照；考勤等 A 的 v2 认证。
4. 真实账号才能验证的（考勤 v2 完整登录、PEC / 实验课、空闲教室需要教务登录的部分用现有测试账号可以验证）标「后续测试」。
