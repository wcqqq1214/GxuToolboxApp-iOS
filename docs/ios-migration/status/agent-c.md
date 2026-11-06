# Agent C 状态

- 当前 Phase：Phase 3 完成（见 COORDINATION `[phase3-done] C` 的附录 A 验收表）；教师查询已用真实样本核对；评教总览所依赖的后端 `/jw/evaluation` 路由未部署（404），保留 TODO(verify)；关键流程 UI 测试需要真实账号 / 校园网，标后续测试。评教的详情 / 评语 / 提交后端未代理，待用户决定；`/jw/evaluation` 无真实样本（后续测试）
- Phase 2 已完成：
  - **ExamKit / ExamUI 拆分**（PLAN §5.1 (a)）：`ExamKit` 无界面，含 `ExamRepository.nextExam / upcomingExams`、`NextExam`、`PendingCourse`；`ExamUI` 是页面。旧 product `FeatureExam` 保留为兼容层（= 两者 re-export），App 已改用 ExamKit + ExamUI
  - **小组件**（`Widget/` + `ClassWidgetKit`）：主屏小 / 中 / 大，锁屏 `accessoryRectangular`、`accessoryInline`；时间线每节课开始、结束各一个条目，另加每天零点；数据来自 `WidgetBridge` 写入 App Group 的 `NextCourses` 快照（已含节假日 / 调课）；视图在 `ClassWidgetKit/Views`，Widget 只是外壳
  - **Live Activity + 灵动岛**（紧凑 / 最小 / 展开）：显示正在上的课或 60 分钟内要上的课；用 `staleDate` 在开始 / 结束时切换界面，计时用系统计时文字，不需要后台更新
  - **App Intents**：今天的课 / 明天的课 / 下一场考试（`ToolboxIntents`，`GxuIntentsPackage` + `GxuAppShortcuts` 在 App target），只读本地缓存
  - **节假日页**（`HolidayView`，只读 `CampusCalendarRepository.current()`，不再请求，内置备份就是最新数据）、**调休补班页**（`TimeShiftView`）
  - **已选课程**（`GET /jw/selected-courses`，GRDB 缓存按学号隔离，按学期分组、搜索、范围菜单）、**未出分科目**（成绩页，已选课程与成绩的差集，通过 `PendingCourseSource` 注入）
  - **选课策略**（校选课查漏）：2021–2026 各年级规则完整移植，每个年级都有"达标 / 空列表 / 必修课 / 学分口径"测试（`ElectiveStrategyTests`，约 45 个用例）
  - **考勤页**（FeatureMisc）：考勤记录（分页、汇总、按日分组）+ 考勤课表（按周，课程上标出勤状态）；内层 `code == 600` 才算成功；未登录 / `sessionExpired(.attendance)` 引导去考勤账号页
  - 考试倒计时标签：只有今日 / 明日开考用红色，其余用主题色（`ExamItem.isUrgent`）；考勤状态图标旁加文字说明并合并无障碍元素
  - 界面修改：学期选择放在内容顶部一行（不放工具栏，避免挤掉标题；A 验收发现的问题已修）；GPA 分隔线与表头；去掉重复信息；不及格只标红分数；`1月23日` / `（30%）` / 同步时间不带秒
- 待真实账号（考勤）：考勤页只用单测和 Mock 数据（`MiscDebugScreens`）验证，字段按 RN 类型定义写，**标 TODO(verify)**：`/attendance/index-data`、`personal-data`、`schedule` 的真实响应
- `/jw/selected-courses` 已用 A 的脱敏样本核对（已选课程、选课策略、未出分科目），测试换成真实 fixture；修了小学期 `term = 3`、`location` 字段、网络课 / 实验课判断三处，见 COORDINATION「[C] 已选课程用真实样本核对」
- PLAN §5.1 (e) 小组件读 SharedStore 的实测：**待真机验证（需要真实 Team ID）**。已确认的：App 与 Widget 的 `.xcent` 都带 `group.com.gxutool.ios`（`strings` 可见），App 能拿到 App Group 容器；扩展运行时是否读到同一容器没有在模拟器上做（这台机器没有 Simulator.app，驱动 SpringBoard 加小组件超出 30 分钟时限，按用户指示停止）。WidgetBridge 同时把"当前学号"写进共享键 `widget.activeStudentId`，所以小组件不依赖 Keychain 就能找到快照
- 设计自查图（不是真实小组件截图）：`ios-native/.screens/widgets/`（ImageRenderer 渲染，含浅色 / 深色 / accented 近似）。**限制**：accented 是去色近似，系统真实的染色合成要在设备上看；`ProgressView(timerInterval:)` 在 ImageRenderer 里渲不出来，截图里换成了静态进度条，真实 Activity 上的效果没有看过
- 页面截图：`ios-native/.screens/c-*-{light,dark}.png`（`-GxuScreen c-exam|c-score|c-gpa|c-holiday|c-timeshift|c-selected|c-strategy|c-attendance[-expired|-nologin]`，内置假数据）
- 没做 / 后端不支持：教务"调课消息"（RN `reschedulingNews`，直连教务 `/xtgl/index_cxDbsy.html`，后端没有代理，按 PLAN 不在 iOS 直连）；"选课课程列表查询"（`courseSelectionList`，同样直连教务）；GPA 累计范围
- 仍待确认的 TODO(verify)：2025/2026 级创业学分不参与"毕业资格"（RN 如此，界面逐项却显示未达标，是规则问题不是数据问题）；考勤课表 `courses[day]` 下标 0 是表头列的假设
- 阻塞 / 等待：无。已按用户指示停在 Phase 2 结束，不开始 Phase 3，等设计审查

---

# Phase 1 行为规格（源自 RN，用于 Swift 移植）

所有请求走 `BackendAPI`（`auth: .jw`）。学期一律用逻辑学期 `1`=秋、`2`=春（`AcademicTerm`），后端 `term` 参数与此一致。所有表带 `studentId`，查询必须带 `studentId`。

## 1. 考试信息（`src/features/examInfo/`）

### 接口
`GET /jw/exam?year=2025&term=2` → `{data: [Exam] | null}`。后端已用 adapter 转换，字段为：

| 字段 | 来源（教务原始字段） | 备注 |
|---|---|---|
| `id` | `sjbh` | 考试编号，如 `随堂-2025-2026学年第二学期本科课程期末考试-计算机网络原理-1073105` |
| `course` | `kcmc` | |
| `classroom` | `cdmc`，空则 `cdbh` | |
| `time` | `kssj` | `2026-07-15(09:00-11:00)`；可能为空或格式不符 |
| `type` | `ksmc` | 如"2025-2026学年第二学期本科课程期末考试" |
| `seat` | 可能不存在 | 教务已不给座位号；缺失按 `""` 处理 |

`data == null` 视为"没有数据"，**仍要用空集合替换该学期缓存**（避免已取消的考试残留）。

### 时间解析 `parseExamTime(time, now)`
- 正则 `(\d{4}-\d{2}-\d{2})\((\d{2}:\d{2})-(\d{2}:\d{2})\)`，不匹配 → `(date: nil, status: .tbd)`
- 开始时间 = 日期 + 开始时分，结束时间 = 日期 + 结束时分（设备本地时区）
- `status`：结束时间 **严格早于** `now` → `.past`，否则 `.upcoming`（结束时间恰好等于 now 仍算 upcoming）
- 返回的 `date` 是**开始时间**，用于排序和展示
- RN 的 dayjs 会把 `2026-02-30`、`25:00` 这类越界值滚动成合法时间；Swift 对越界值统一判 `.tbd`。这是有意的差异，测试里单独标出
- `date` 和 `status` **不入库**，每次读取时按 `time` 重新算，所以考试结束后无需刷新状态就会变化

### 排序与分组
- 排序键：`upcoming` < `tbd` < `past`；`upcoming` 按开始时间**升序**；`tbd`、`past` 按开始时间**降序**（`date == nil` 当 0）
- 展示分两组：「即将开考」= upcoming + tbd（先 upcoming 后 tbd）；「已结束」= past。每组标题带"N门"，空组不显示
- 页面顶部"共有 N 条结果"

### 倒计时徽章
- 仅 `upcoming` 且 `date` 有效时计算：按**日历天**差（`startOfDay(date) - startOfDay(now)`）。0 → "今日开考"，1 → "明日开考"，其余 "N天后"，负数 → 无
- RN 注释写"≤3 天才醒目"，但代码对**所有** upcoming 都显示倒计时并用红色。iOS 沿用代码行为，只有 `.tbd`（"时间未知"，警告色）和 `.past`（"已结束"，灰色）用别的文案
- 卡片：课程名；时间显示 `MM月dd日 HH:mm`（只有开始时间），`date` 为 nil 时显示原始 `time`，原始值为空显示"时间未定"；考场 `classroom`；座位号仅在非 past 时显示，空显示"未知"；底部显示 `type`；past 整体透明度 0.6

### 缓存策略
- 表 `exam_info`，RN 主键 `(id, studentId, year, term)`，字段 course / classroom / time / type / seat / updatedAt
- 进入页面或切换学期：先读本地 `(studentId, year, term)` 立即显示，再后台请求；成功后在**一个事务内** delete 该切片再 insert 新数据，并刷新界面
- RN 的问题：远端失败时 `error` 为真，页面只显示"查询失败"并**隐藏已缓存的数据**。iOS 改为：有缓存就继续显示缓存，顶部加一条错误提示（`GxuError.userMessage`）和重试；没有缓存才整页显示错误视图
- 状态：首次加载无数据 → 整页 loading；有数据时切换学期 → 小 loading；空 → "本学期暂无考试安排"

### 学期选择器（RN `ChooseTerm`）
- 年份列表：从入学年份起 `study_years` 个学年（默认 4），过滤掉 `year > 当前学年`。当前学年 = 当前月份 < 9 ? 今年-1 : 今年
- 默认选择：已开学 → 当前学期；未开学（假期）→ 默认看"刚结束的学期"（`prevTerm`：春(2)→同年秋(1)，秋(1)→上一年春(2)），若回退后早于入学年份则退回当前学期
- 学期按钮：秋季 / 春季（考试信息和成绩页不含"全学年"和"全历史"；GPA 页有）
- 依赖 A 的资料（入学年份、学制）和 B 的开学日（见顶部通知）

## 2. 成绩（`src/features/examScore/`）

### 接口
`GET /jw/score`，参数：`pageSize=1000`、`pageNo=1`、`orderBy=desc`、`order=cjbdsj`（两个参数名在 RN 里是互换的，但后端按此接收，**照抄不要"纠正"**）、可选 `year`、`term`。需要先 `ensureAuthenticated(.jw)`。

响应 `{code, data: {totalCount, totalPage, currentPage, items: [Score]}, message}`。`Score`：

| 字段 | 来源 | 备注 |
|---|---|---|
| `id` | `jxb_id` | 教学班 ID；既是主键，也是平时分接口的 `id` |
| `year` | `xnm` | Int，学年起始年 |
| `term` | `xqm` | `"3"`→1，`"12"`→2，**其他（如小学期 16）→0**，所以按 term 1/2 查询不会包含小学期 |
| `course_name` | `kcmc` | |
| `credit` | `xf` | Double |
| `score` | `cj`，不是数字时用 `bfzcj` | "优秀/良好"等等级制成绩由 `bfzcj` 换成数字。两者都不是数字时 JS 里是 `NaN`，JSON 序列化后为 `null`，**Swift 必须按可选值解码** |
| `teacher_name` | `jsxm` | |
| `upload_at` | `cjbdsj`，空则 `tjsj` | `yyyy-MM-dd HH:mm:ss` |

后端是否同时返回 camelCase 副本（`courseName` 等）未确认，Swift 解码只用 snake_case 一套，见 TODO(verify)。

### 查询规则 `normalizeQuery(year, term)`
- `year` 为空、≤0 或非整数 → 无效，清空列表
- `term` 为空 / 0 → **全学年**：分别请求 term 1 和 term 2（`allSettled`），合并结果。部分失败时用成功的那部分；全部失败才抛错；全部成功但都没数据 → 视为没有新数据
- 其他值必须是 1 或 2
- RN 用请求版本号防止旧请求覆盖新学期；Swift 用 `Task` 取消 + 学期校验

### 展示
- 每行：`term == 1 ? "\(year) 秋" : "\(year+1) 春"`、课程名、成绩；`score < 60` 整行红色
- 点击行展开：**平时成绩明细**（见下）+ 发布时间 `upload_at`、学分 `credit`、绩点 `calculatePoint(score)`、教师
- 页面顶部：显示"上次同步 MM月dd日 HH:mm:ss"（取缓存首条的 `updatedAt`）、同步中的小转圈，以及"绩点计算器"入口
- 缓存先显示，再后台刷新；列表按 `upload_at` 降序
- **未出分科目**：同学期已选课程的 `classId` 与成绩 `id` 的差集，实验类课程加"(实验)"。仅在选了具体学期时显示，全学年不显示。依赖 FeatureCourse 的已选课程（Phase 2），Phase 1 先留好接口，不显示

### `calculatePoint(score)`（单门绩点，展示用）
`score` 不是数字 → `"N/A"`；`score < 60` → `"0"`；否则 `(score - 50) / 10`，保留两位（`toFixed(2)`）。例：60→`1.00`，85→`3.50`，100→`5.00`。

### 平时成绩 `GET /jw/score/usual?year=&term=&id=`
- 响应 `{code, data: [{name, ratio, score}], message}`。`name` 如"平时成绩"、"期末成绩"、"总评"；`ratio` 是不带 % 的字符串，总评等没有比例时为 `"N/A"`；`score` 是字符串
- 展示：`"\(name || "暂无")"`，`ratio != "N/A"` 时追加 `（\(ratio) %）`；右侧 `score || "暂无"`
- 展开时才请求；状态 idle / loading / success / error（失败显示"获取平时成绩失败"）
- RN 缓存**实际是坏的**：落库时 `JSON.stringify(res)` 存了整个响应对象而不是 `res.data`，下次读缓存时 `Array.isArray` 不成立，所以每次都重新请求。iOS 修正：只存 `data` 数组；空数组不当作已缓存（RN 用"长度 > 5"判断，等价于不缓存 `[]`）
- RN 的另一个 bug：成绩刷新时 `upsert` 把 `usual_score` 重置为 `""`，会擦掉已缓存的平时分。iOS 刷新成绩时**保留** `usual_score`

### 缓存与账号隔离（需要修正的点）
- 表 `score`：`(studentId, id)` 为主键，字段 year / term / courseName / credit / score(可空) / teacherName / uploadAt / usualScoreJSON(可空) / updatedAt。**必须带 `studentId`，每个查询都按它过滤**（RN 的表没有这一列，切换账号会看到别人的成绩）
- 写入：一个事务内按 id upsert，保留 `usualScoreJSON`；同时删除该 `(studentId, year, term)` 切片中不在本次响应里的行（RN 只增不删）。全学年的两个请求按学期分别处理，只处理成功的学期
- 错误不能吞：请求失败要抛 `GxuError`，界面用 GxuDesign 错误视图；有缓存时保留缓存加提示条

## 3. GPA 计算器（`src/hooks/useGpa.ts`、`GPAcalculator.tsx`）

依据《广西大学普通本科学生课程修读、考核及成绩管理办法（2019年修订）》。

```
对列表中每门课（item.score, item.credit）：
    point = score / 10 - 5
    if score >= 60:  gpaNumerator += point * credit
    denominator   += credit          // 不及格的课程学分也计入分母
    wamNumerator  += credit * score  // 不及格同样计入
GPA = gpaNumerator / denominator
WAM = wamNumerator / denominator    // 加权平均成绩
列表为空 → GPA = 0, WAM = 0
```

- 不排除任何课程：没有"哪些课不计入"的规则，只有"<60 分绩点为 0 但学分仍计入分母"。没有 K 系数（取 1）
- 显示精度：GPA 三位小数，WAM 两位小数（官方办法写两位，RN GPA 用三位，沿用 RN）
- 页面：顶部大字显示 `GPA:x.xxx` 或 `WAM:xx.xx`，右侧按钮在"平均学分绩点 / 加权平均成绩"之间切换（按钮文字显示的是**切换后的目标**）；"计算方法"旁的 ? 打开说明，文本逐字取自 `GPAcalculator.tsx` 中 Modal 的内容（办法 (一)–(五)）；下方表格三列：课程名 / 绩点（`calculatePoint`）/ 学分（保留 1 位）
- 学期选择器与成绩页共用 `useScore(year, term)`，可从成绩页带 `{year, term}` 进入。GPA 页的选择器比成绩页多"全学年"；"全历史"在 RN 里 `year == ""` 会被 `normalizeQuery` 判无效，结果是空列表（RN 的 bug）
- **边界情况（RN 行为会出 NaN，iOS 另行处理）**：
  1. `score` 为 `null`/非数字：RN 的 `NaN` 会污染整个结果。iOS 跳过这门课（分子、分母都不计）
  2. 分母为 0（列表非空但学分全为 0）：RN 得到 `NaN`。iOS 返回 0
  3. `credit` 为 `NaN`（`xf` 无法解析）：同 1，跳过
- iOS 增加"累计"范围（全部已缓存学年）的计划：Phase 1 先做学期和全学年；累计需要逐学年拉取，放在有时间再做，并写进 TODO

## 4. Swift 结构与测试计划

结构（`ios-native/Packages/FeatureExam/`）：`Models`（`Exam`、`ExamStatus`、`Score`、`UsualScoreItem`）→ `API`（`ExamAPI`、`ScoreAPI`，只依赖 `BackendAPI`）→ `Repository`（GRDB，迁移前缀 `exam`，如 `exam.v1.createExamInfo`、`exam.v1.createScore`）→ `@Observable` ViewModel（`ExamInfoViewModel`、`ScoreViewModel`、`GpaViewModel`）→ View。对外只暴露 `ExamFeature { static let migrations; static func makeRootView(...) }` 与需要共享的模型。

纯逻辑拆成无依赖的值类型（`ExamTimeParser`、`GpaCalculator`、`ExamSorting`），便于测试。

单元测试（Swift Testing）。期望值用 RN 的 TS 代码对同一组输入计算后写入：

- `parseExamTime`：`2026-07-15(09:00-11:00)` 在 now 为开考前 / 考试中 / 结束后 / 结束时刻恰好相等；空串、`待定`、缺括号、越界日期 → tbd
- 排序分组：upcoming 升序、tbd/past 降序；混合列表分到两组；`date == nil` 的位置
- 倒计时：今日 / 明日 / N 天后 / 跨午夜（23:30 vs 次日 00:10）
- `calculatePoint`：`nil`、59、60、85、100、59.5
- GPA：手工算例 `[(90,3),(75,2),(59,1),(60,2)]` → GPA = (4×3 + 2.5×2 + 1×2) / 8 = 2.375，WAM = (270+150+59+120) / 8 = 74.875；空列表；全部不及格（GPA 0、WAM 非 0）；零学分；`score == nil` 的课被跳过；小数学分（3.5、2.5）
- 解码：Exam（含缺 seat、`time` 为空）、Score（`score` 为 `null`、`term` 为 0、等级制）、Usual（`ratio = "N/A"`）
- Repository（内存数据库）：按 studentId 隔离（两个账号互不可见）；`replaceByTerm` 后已取消的考试消失；score upsert 同一 id 不产生重复行，并保留已缓存的 `usualScoreJSON`

## 5. 实现顺序（bootstrap 发布后）

1. `git rebase ios-native`，确认 `scripts/build.sh`、`scripts/test.sh` 能跑
2. FeatureExam 纯逻辑 + 测试（`ExamTimeParser`、`GpaCalculator`），无 UI 依赖，可最先完成
3. 模型与解码、Repository + 迁移
4. API + ViewModel（本地优先，再后台刷新）
5. 考试信息 → 成绩 → GPA 三个页面，接入 `FeatureRegistry` 和 `ToolboxCatalog` 各自一行
6. 模拟器截图（浅色 / 深色），更新本文件，按 PLAN §4.1 发布

## TODO(verify)

已用 A 的真实脱敏响应（`Fixtures/sanitized/`，测试见 `RealFixtureTests`）和真实账号 e2e 核对：
- [x] `/jw/score`：snake_case 与 camelCase 两套同时存在（另有 `updateTime`），Swift 只读 snake_case（camelCase 作回退）；样本 100 条 `score` 全是数字，没有 `null` 也没有缺字段，解码仍按可选处理；`credit` 有整数和小数；有 1 条 `term = 0`；`upload_at` 可为空串；`id` 不重复
- [x] 外层都是 `{code, message, data}`，`getData` 直接可用
- [x] `/jw/exam` 没有 `seat` 字段；结果里混有往届缓考/补考
- [x] 成绩真实 GPA 对照：全部 100 条、2023 秋、2023 学年三组期望值与 RN 公式一致
- [x] `/jw/score/usual?year=2025&term=1&id=...`：真实账号下返回平时成绩/期末成绩/总评三项，`ratio` 为 "40"/"60"/"N/A"（e2e 截图可见）。传 term 1/2 正确
- [x] 学期选择器所需的入学年份/学制：A 的 `services.profiles` 已接入

仍未确认（均不阻塞）：
- 越界日期时间（Swift 判 tbd，与 RN 滚动进位不同，有意为之）
- 成绩 `term = 0`（未分学期）的记录：按 term 1/2 查询看不到，全学年也看不到
- GPA 精度（RN 三位，官方办法两位）以用户确认为准

---

# 审查循环决策日志（pstack interrogate，C 的路径）

## 第 1 轮（3 个对抗 subagent：考试 / 小组件、课程 / 选课策略、考勤 / 教师 / §6 规则）

验证后的发现 8 条，全部修复并加了回归测试：
1. 教师搜索：翻页请求在途时发起新搜索，`isLoadingMore` 永远不清，之后无法翻页 → `search()` / `reset()` 里复位（`TeacherSearchRaceTests`）。
2. 考勤解码：超出 Int 范围的数字（`1e30`）转 Int 崩溃 → 先判范围，当缺失（`LenientNumberTests`）。
3. 已选课程解码：`year` / `term` 同样的崩溃 → 同样处理，写缓存时被"学年学期无效"拒绝（`HostileInputTests`）。
4. 考勤：下拉刷新的旧响应在切换学期后覆盖新学期的记录 → `loadVersion` 版本号，过期响应作废（`AttendanceRaceTests`）。
5. 小组件：最后一节课结束后 App 刷新快照，`today` 为空，"今天的课已上完"被误报成"今天没有课" → 刷新时另记"这一天有过课"（共享键 `widget.hadClassesDay`，只对当天有效），时间线用它（`HadClassesTodayTests`）。
6. 已选课程：同一教学班在一个响应里重复，Swift 留第一条、RN 留最后一条 → 改为留最后一条（位置保持第一次出现的位置）。
7. 节假日 / 考勤日期解析：`2026-02-30` 被 Calendar 顺延成 3 月 2 日（"编造日期"）→ 往回取一次校验，无效返回 nil，条目丢弃。
（5 与 1 同属 widget / misc 各自的根因，未合并。）

未修 / 判断：
- 对抗者指出"教师工号 `000000` 当网络课"偏离 RN 的 `isOnline` 规则：保留。理由：A 的脱敏说明明确 `000000` 是网络课占位工号；A 的真实原始数据上 `teacher == "网络教师"` 与 `teacherId == "000000"` 是同样的 7 门；脱敏样本里教师名被替换，只有工号还在。该判断已写进代码注释。
- 其余被丢弃的（未复现、纯风格、空 courseId 等）共 16 条，不再提。

## 第 2 轮（2 个对抗 subagent：考试 / 小组件、课程 / 考勤 / 教师）

验证后的发现 3 条，全部修复并加了回归测试：
1. 设备日历设成佛历 / 日本历 / 农历 / 民国历时，考试时间按 `Calendar.current` 拼年月日，年份完全错（状态、倒计时、排序、首页卡片、Intent 都受影响）→ `Calendar.gregorianEquivalent`（同时区公历），考试解析 / 展示、学年推算、节假日日期、考勤日期、Intent 文案都先转公历（`NonGregorianCalendarTests`，5 种日历）。ScheduleKit 里 `TermCalendar` 等同样依赖调用方的日历，是 B 的路径，已写进 B 的请求。
2. 考勤：过期请求失败时把错误条盖在新学期的成功数据上 → `catch` 里也检查 `loadVersion`（`AttendanceStaleFailureTests`）。
3. 考勤课表：`connectCount` 给 `Int.max` 时 `row + 1 + connectCount` 溢出崩溃 → 连续节数限制在表剩余行数内（`AttendanceHostileScheduleTests`）。

丢弃 6 条（没有证明：term 0 残留行取决于后端行为、`isLoading` 卡住在下次成功加载时复位、选课范围切换的数据库时序等）。

## 第 3 轮（2 个对抗 subagent；B 中途被限额打断，结果没有拿到）

A 验证后的发现 4 条，全部修复并加了回归测试：
1. 小组件快照和 App Intent 没算用户选的冲突课程和自定义日程（和 App 里的"今天"不一致，Intent 还会说"有 2 节课"而实际只能上一门）→ `SnapshotProvider` / `ScheduleQuery` 改用 B 提供的 `ScheduleRepository.cachedSnapshot`（已叠加节假日 / 补班、冲突选择、自定义日程）（`SnapshotConsistencyTests`）。
2. `ElectiveStrategy.number` 遇到超大 / 无穷学分崩溃（`Int(v)`）→ 非有限返回 "0"，超大不转 Int。
3. 学分 `"NaN"` 解码成 NaN，写库触发 NOT NULL 失败，一行坏数据让整个刷新失败 → 非有限当缺失（0，RN 的 `Number(x) || 0`）。
4. 已选课程 / 选课策略 view model：同一范围内下拉刷新的旧响应覆盖新数据 → `loadVersion` 版本号。
（回归测试：`NonFiniteNumberTests`、`SnapshotConsistencyTests`。）

收尾时查清的一次测试失败：`SnapshotConsistencyTests` 一度失败，原因是**测试写错**不是产品 bug——测试里算冲突组键用的课表没带教室，而数据库里存的课表带教室，课程 id / 冲突键含教室，两边键不同，所以冲突选择没生效。改成两处共用同一份课表，断言没有改动。

## 结束状态
- 轮数：3（第 3 轮 B 未完成）；按用户决定不再开新一轮。
- RN / 后端缺口（保留，不处理）：调课信息、选课课程列表（后端未代理）；期末评教（`GET /jw/evaluation` 404，详情 / 评语 / 一键评教 / 提交无接口）；`GET /feedback/{userId}` 401。
- 已知偏离 RN 但有意保留：教师工号 `000000` 视为网络课。
- 未验证：第 3 轮 B（渲染、Dynamic Type、无障碍）没有结果；真机 / 真实账号相关项仍标"后续测试"。

---

# 用户真机试用后的修改（[user-fixes-1] C）

- 绩点计算器：默认全部学期总绩点；可切某学年的全学年 / 单个学期；小学期计入；一次不带 year / term 的请求；失败不显示错误的总数。`GPA 累计范围没做` 的 TODO 已完成。
- 教师查询按 RN 重做：领导点击进入详情（`profile?name&school=校领导`）、头像（http→https + 姓名占位）、空字段整行隐藏。
- 待用户真机反馈：头像显示、领导详情、全部学期总绩点。

# v2.2 校选课进度（[v22-aligned] C 之一）

- `ElectiveStrategyView` 入口改为后端结果页（`GET /jw/elective-progress`）：校验 `studentId` 等于当前账号、整份结果按学号缓存、新刷新使旧请求作废、刷新失败保留上次结果并提示、`complete=false` 或 `isQualified=nil` 显示"待核对"而不是"未达标"，数值格式移植 `progressDisplay`。
- 旧本地规则页保留为 `LegacyElectiveStrategyView`（调试屏 `c-strategy-legacy`），年级规则和测试不删，不再路由。
- 后续测试：没有真实响应样本（已向 A 请求），模型按 RN schema 构造，测试夹具是构造数据。
