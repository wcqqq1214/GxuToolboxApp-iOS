# Agent C 状态

- 当前 Phase：Phase 2。ExamKit/ExamUI 拆分已完成
- 已完成：
  - FeatureExam：模型与解码、`ExamTimeParser`/排序分组/倒计时、`GpaCalculator`、`TermOptions`、GRDB 仓储（按 studentId 隔离，迁移 `exam.v1.*`）、`ExamAPI`/`ScoreAPI`、三个 ViewModel、三个页面（考试信息、成绩查询含平时分展开、绩点计算器）
  - 工具箱三行已接入 `ToolboxCatalog`（examInfo / examScore / gpa）
  - 默认学期用 B 的 `ScheduleRepository.currentTermInfo()`（假期看刚结束的学期，早于入学年份则看当前；拿不到时按月份推断）；学年范围用 A 的 `services.profiles`（入学年份起 `studyYears` 个，不晚于当前学年）。TEMP(coord-1)、TEMP(coord-2) 已删除
  - 状态视图换用 GxuDesign（`GxuLoadingView`/`GxuEmptyView`/`GxuErrorView`/`GxuStaleBanner`）：有缓存时刷新失败只贴提示条，没有缓存才整页显示错误
  - 39 个单元测试（含用 A 的真实脱敏 fixture 的 `RealFixtureTests`，期望值由 RN 同一公式独立算出）；App、Widget 构建通过；全部 package 的 `test.sh` 通过
  - 真实账号 e2e 自查（浅色/深色）：`ios-native/.screens/real-{examInfo,examScore,gpa}-{light,dark}.png`。成绩页展开可见平时成绩（含占比）、总评、发布时间、学分、绩点、教师；GPA 页数值与成绩页一致。该账号是 2022 级，默认学期（2026 秋）已超出学制，所以截图用本地临时覆盖指到 2025 学年（覆盖代码未提交）
- 进行中：无
- 阻塞 / 等待：无
- 给其他 agent 的通知：见 COORDINATION 的 `[phase1-done] C`
- 未做 / Phase 2：未出分科目（依赖已选课程）；GPA "累计"范围；`ExamKit`/`ExamUI` 拆分（PLAN §5.1 (a)）；小学期（`term = 0`/3）后端不支持查询（§5.1 (d)），UI 只提供 1/2

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
