# Agent B 状态

- 当前 Phase：Phase 2 进行中
- Phase 2 已完成：
  - 修复课表刷新把 CancellationError 显示成错误条（`Error.isCancellation`，有测试）
  - 节假日 / 调课（`CampusCalendarRepository`、`CalendarOverlay`）：data.json 获取 + GRDB 缓存 + 内置备份，叠加到课表（休息日移除、补班日显示被调课程并带“补”标记、假期整天块），小组件快照同步；用法见 COORDINATION「[B] 节假日 / 调课数据」。节假日不做远程更新（用户决定），内置备份即最新数据（到 2027 年元旦），之外的日期无假期不报错；仍远程获取 timeShift。工具箱已删除“空教室”
  - 首页「今天」标签 + 底部“下一件事”附件（课程 + ExamKit 的考试）；冲突课程选择持久化（`schedule.v1.createConflictChoice`）；设置页挂上统一认证 / 考勤账号入口
  - 自定义日程（添加 / 编辑 / 删除 / 管理列表，GRDB）、课表外观与课程 / 考试详情显示偏好（`SchedulePreferences`）、设置页「课表与考试」
  - 首页按协调者意见调整（今天标签不显示底部附件、考试去重、座位文案、课程结束折叠 + 明天预览）；`-GxuForceLegacy` 开关；ScheduleUI 抽出 `ScheduleBoard`，新增只读 `StaticScheduleView`（班级课表用）
  - FeatureCampus：班级课表（筛选 + 班级列表 + 只读周网格）、全校课表（此刻有课的班级）；真实账号验证通过（49 个班 / 31 个在上课）
  - 截图：`ios-native/.screens/holiday-week-{light,dark}.png`、`home-{light,dark}.png`
- Phase 1 状态（保留）：已完成（待用户验收）
- 已完成：
  - GxuDesign v1：`GxuTheme`（强调色 + 外观模式，持久化）、`GlassGroup` / `GlassButton` / `.gxuGlass()` / `.gxuGlassID` / `.gxuTabBarMinimizeOnScroll` / `.gxuTabAccessory`（iOS 18 降级 Material）、`ContentCard`、`GxuLoadingView` / `GxuEmptyView` / `GxuErrorView` / `GxuStaleBanner`、`CourseTint`（浅 / 深色对比度 ≥ 4.5:1，有测试）、`README.md`
  - Shell：三个 Tab（课表 / 工具箱 / 设置）、`ToolboxCatalog`（17 项，全部“即将上线”，每项一行）、`SettingsHomeView`（账号入口、外观、占位项）
  - ScheduleKit 另提供给 C：`ScheduleRepository.currentTermInfo()`（当前学期 + 是否已开学）
  - ScheduleKit（无 UI 依赖）：模型（宽容解码）、周次解析与展开、`TermCalendar` / `TermResolver`（开学日、本地时区按天、兼容带时区的 ISO 串）、冲突分组（传递闭包）、`NextCourseCalculator`、`CourseColorAssigner`（4 → 3 个色盘）、周次 / 地点格式化、时间线位置、GRDB 缓存（课表快照带 studentId，迁移 `schedule.v1.*`）、`ScheduleRepository`、小组件快照（`ScheduleKit.widgetSnapshotKey`）。36 个测试
  - ScheduleUI：周网格（节次列、星期日期表头、今天高亮、红色当前时间线、课程块不用玻璃）、横向分页切周、浮动玻璃控件（上一周 / 本周 / 下一周，`glassEffectID` 变形）、周次跳转菜单、学期切换菜单、课程详情 sheet（detents、冲突组列出全部）、下拉刷新、离线保留缓存 + 顶部提示、未登录 / 加载 / 失败状态
  - 用真实账号（`scripts/run-e2e.sh`）跑通课表页，浅色 / 深色都截图自查；改进：打开本周时自动滚到当前时间附近、回到前台自动刷新（30 秒节流）、离线提示的时间固定成中文格式
  - 设置页账号入口显示 “学号 · 学院”（`services.profiles`，先缓存后台更新）
  - 测试改用 A 脱敏的真实 fixture（36 个）；`PracticeCourse.title` 去掉练习课名里内嵌的教师和周次
  - DEBUG 调试开关：`-GxuDemo`（内置假数据）、`-GxuDemoOffline`（前两次请求成功后全部失败，看离线状态）、`-GxuTab toolbox|settings`
  - 截图（`ios-native/.screens/`，已 gitignore）：真实账号 `e2e-light-200355.png`、`e2e-dark-200355.png`；离线 `demo-offline-light.png`；设置页 `demo-settings-light.png`；早期的 `schedule-light.png`、`schedule-dark.png`、`toolbox-light.png`
- 进行中：无
- 阻塞：无
- 给其他 agent 的通知：见 `ios-native/COORDINATION.md` 的 “[B] GxuDesign v1 / 课表发布说明”
- 已知问题：浮动的上一周 / 下一周按钮会盖住下方的课程块（滚动即可），长课程名（如 “混凝土结构基本原理”）在窄列里会换成 3 行；冲突角标在按钮下面时看不到。Phase 3 的视觉打磨再处理
- 未做（留给 Phase 2）：冲突课程“选中哪一门”的持久化（现在默认组内第一门）、`tabViewBottomAccessory` 下一节课、课程颜色 / 显示项设置、调课 / 假期 / 考试 / 实验 / 考勤覆盖层、分享图片、点课程打开地图
- TODO(verify)：
  - [x] `GET /jw/schedule/personal` 真实响应（A 的脱敏 fixture）：`weeks` 是 `[Int]`；`practiceList` 字段是 `courseName/time/teacher`；`theoryList` 全部字段类型规整；多一个 `personalInfo`，已忽略。测试已换成真实 fixture（26 门理论课条目、157 次上课、29 个冲突组）
  - [x] 练习课 `courseName` 内嵌教师和周次（`创新创业实践●教师70(共16周)/1-16周/无`）：新增 `PracticeCourse.title` 截断到第一个 ●◆★○ 标记，显示请用它（Phase 3 的实践课页面用）
  - [x] 同名同节次课程是否撞 id：真实数据没有撞；同一门课分周换教室会是两个条目（`地下结构设计软件`），Swift 端 id 带教室和教师，不会撞
  - [x] `GET /jw/profile/startDay`：UTC 零点 ISO 串、无 `is_current`、5 个学期（`week` 为 20 / 19）。已按日历日解析，当前学期由客户端判定（有测试）
  - [ ] **`data` 为 null**：测试账号拿不到这种响应（RN 注释称后端 parseSchedule 失败时返回 null）。已防御性处理并有测试：视为错误、不覆盖缓存。待有机会复现再确认
  - [ ] 逻辑学期 3（小学期）后端是否支持；RN 把旧教务码 3 映射到逻辑 1，与 PLAN §3 的逻辑 3 = 小学期冲突。真实 startDay 只有 term 1 / 2，Phase 1 不受影响
  - [ ] 第 9 / 10 节作息重叠（18:55 / 18:45）是否真实（真实课表里没有 9–10 节的课，无法从数据确认）
  - [ ] 调课 `data.json` 是否继续作为数据源（Phase 2）
  - [ ] iOS 26 / 27 真机上玻璃按钮 `interactive` 和 `glassEffectID` 变形动画（模拟器截图只能看静态）

---

# 课表行为规格（来自 RN 源码，供 Swift 重写对照）

来源：`src/features/courseSchedule/**`、`src/features/classCourseSchedule/{api,utils}`、`src/components/tool/infoQuery/courseSchedule/TimeSchedule.tsx`、`src/hooks/useCourseData.ts`、`src/js/nextCourses.ts`、`src/features/widget/widgetScheduleData.ts`、`gxu-tool-adapters/adapter-jw`（`schedule/schema.ts`、`utils.ts`）。

## 1. 数据来源（iOS 只走后端）

| 数据 | 接口 | 说明 |
|---|---|---|
| 个人课表 | `GET /jw/schedule/personal?year=&term=` | `term` 为逻辑学期 1/2（`AcademicTerm.term`）。响应 `{data: Schedule}`，**已解析**，`data` 可能为 `null`（后端 parseSchedule 失败）。需 `auth: .jw` |
| 学期开始日 | `GET /jw/profile/startDay` | 响应 `{data: [TermStartDay]}`，见 §2 |

不移植：RN 的 `POST /jw/schedule/personal`（原始教务结构）。

### Schedule（适配器输出，Swift 端的解码目标）

```
Schedule {
  theoryList: [TheoryCourse]
  practiceList: [PracticeCourse]
}
TheoryCourse {
  building: String        // 楼号 lh，如 "西三教"
  venueName: String       // 教室 cdbh || cdmc，如 "西3-406"
  sectionRange: String    // jcs，如 "1-2"；默认 "1-2"
  begin: Int              // jcs 拆出，1...13
  end: Int
  courseName: String      // kcmc，默认 "课程名称"
  weeks: [Int]            // zcd 已展开，升序去重
  teacher: String         // xm
  credits: String         // xf
  courseCategory: String  // kclb
  examMethod: String      // khfsmc
  weekday: Int            // xqj，1=周一…7=周日
  qqGroup: String
  enrollmentCount: Int    // xkrs
  seatCount: Int          // zzrl
}
PracticeCourse { courseName: String, time: String /*"1-16周"*/, teacher: String }
```

- 所有字段在适配器里都有默认值（缺失 → 空串 / 默认值），Swift 解码也要宽容：缺字段给默认值，不要整体失败。`xqj/xkrs/zzrl` 原始是字符串转数字，转失败为 `NaN`；Swift 端按 0 处理，且 `weekday` 不在 1...7 的课程**丢弃**。
- `weeks` 以后端返回为准（后端已展开）；Swift 仍需实现一份 `parseWeeks` 用于班级课表之外的场景和测试（见 §3）。

## 2. 学期开始日

`TermStartDay { year: Int, term: Int(逻辑1/2), day: ISO8601 字符串, week: Int(本学期总周数), is_current: Bool }`

- 取全部学期后在客户端重新判定 `current`：按 `day` 升序，第一个满足 `now < day + week 周` 的是当前学期；都不满足取最后一个。**不信任后端的 `is_current`。**
- 需要同步（重新拉取）的时机：本地没有目标学期，或当前学期已结束（`now > day + week 周 - 1 天`）。
- 派生量：`isStarted = !(now < day)`（按天）；`isEnded = now > day + week 周`（按天）。
- 日期一律按**本地时区、按天**计算。`day` 取前 10 位 `YYYY-MM-DD` 当作本地日期（widget 代码就是这样做的），避免 UTC 偏移导致差一天。
- 未登录或接口失败：返回空列表，保留旧缓存。无缓存时 RN 回退到 `2025-09-08`；Swift 端应改为显式的 `missingStartDay` 状态，不要硬编码日期。
- RN 里已知问题：`useStartDay(year, term)` 在调用方不传学期时返回"当前学期"，导致切学期后周次错位。Swift 端 `startDay(for: AcademicTerm)` 必须按学期取。

## 3. 周次展开

`parseWeeks(zcd)`（后端已做，Swift 端复刻用于测试和兜底）：
1. 按 `,` 切段；
2. 每段去掉 `周` 和括号内容后 trim，空段跳过；
3. 含 `-` → `[start...end]`；原段含 `(单)` 只留奇数，含 `(双)` 只留偶数；
4. 否则当作单个数字，非数字跳过；
5. 全部合并、去重、升序。

例：`"1-4周,6-9周,11-14周"` → `[1,2,3,4,6,7,8,9,11,12,13,14]`；`"1-16周(单)"` → `[1,3,...,15]`；`"5周"` → `[5]`。

展开成事件：每门课对 `weeks` 中每个 `week` 生成一个 `CourseOccurrence`，`id = "\(courseName)-\(week)-\(weekday)-\(sectionRange)"`。注意这个 id **不唯一**（同名同节次同周的两个班/教室会撞 id），Swift 端 id 要额外带上教室或下标。

具体日期：`date = termStart + (week-1)*7 + (weekday-1)` 天。`week` 非整数或 `<1` 的丢弃。

当前周：`ceil((now - startDay) / 7天)`，学期未开始为 ≤0，已结束超过总周数；UI 要把它夹到 `1...weekCount`，并用 `isStarted/isEnded` 决定"回到本周"是否显示。RN 此处用的是 `ceil` 的浮点周数；Swift 用日历天数差 `days / 7 + 1`（按天、向下取整）更稳，注意与 RN 在周日边界处一致（startDay 是周一，所以两者等价）。

## 4. 作息时间（13 节）

| 节 | 开始 | 结束 |
|---|---|---|
| 1 | 08:00 | 08:45 |
| 2 | 08:55 | 09:40 |
| 3 | 10:00 | 10:45 |
| 4 | 10:55 | 11:40 |
| 5 | 14:30 | 15:15 |
| 6 | 15:20 | 16:05 |
| 7 | 16:25 | 17:10 |
| 8 | 17:15 | 18:00 |
| 9 | 18:10 | 18:55 |
| 10 | 18:45 | 19:30 |
| 11 | 19:40 | 20:25 |
| 12 | 20:30 | 21:15 |
| 13 | 21:20 | 22:05 |

- 注意第 9 节结束 18:55 晚于第 10 节开始 18:45，两节时间重叠，是学校作息本身如此，不要"修正"。
- 课程时间 = `begin` 节的开始 ～ `end` 节的结束。`begin/end` 越界（不在 1...13）的课程丢弃。
- 作息表目前在 RN 里可由用户在 `courseDataStore.timeSpanList` 修改；iOS Phase 1 先写死为常量，放在 ScheduleKit，供小组件共用。

## 5. 下一节课 / 今日 / 明日

以 `widgetScheduleData.getWidgetSchedule` 为准（`src/js/nextCourses.ts` 是旧实现，有 bug：用 `moment().day(weekday)` 周日会跳到下一周、用 `periodCount` 而不是 `sectionRange`）。

```
occurrences = 全部课程 × 周次展开，计算 startsAt / endsAt（本地时间）
sorted      = 按 startsAt 升序
today       = date == 今天 && endsAt > now      // 正在上的课也算今天
tomorrow    = date == 明天
next        = 第一个 startsAt > now             // 正在上的课不是 next
nextRefreshAt = min(第一个 endsAt > now 的课的 endsAt + 1s, 次日 00:00:01)
state       = ready | missingSchedule | missingStartDay | error
```

- `nextCourses(at: Date) -> NextCourses`：纯函数，入参为课表快照 + 学期开始日 + 时间；这是 ScheduleKit 的核心，要用 fixture 单测，覆盖：周日、跨周、正在上课、当天最后一节课已结束、学期未开始（第 1 周之前）、学期结束后（返回空，UI 显示"所有活动已结束"）、两节课时间重叠。
- 首页 Banner 的 `useNextEvent` 还会混入考试和假期（取 `begin` 节的开始时间，最早且晚于 now 者）；这属于 Phase 2 的首页，Phase 1 的 `next` 只算课程。
- 距离描述：`diff <= 0 → 今天`，`1 → 明天`，否则 `N天后`（按天，`startOf day` 比较）。

## 6. 冲突课程（同一天同时段多门课）

- 渲染分组：同一天的课程按"时段相交"分组：`a.begin <= b.end && b.begin <= a.end`；分组算法是贪心——新课与组内任一成员相交就并入该组（组之间不会再合并，所以 A、C 不相交但都与 B 相交时，取决于顺序可能分成两组；Swift 端应改成传递闭包的区间合并）。
- 组内只有 1 门 → 正常课程块；`>1` → 一个"堆叠块"，范围为组内 `min(begin)...max(end)`，右上角角标显示门数，显示"当前选中"的那一门，点击弹出冲突列表。
- 选中规则：每一组冲突课程以排序后的 key 数组标识，key = `courseName + "_" + teacher`；偏好存 `[{courses: [sortedKeys], active: key}]`；没有偏好时默认组内第一门；偏好里的 key 不在当前组时回退第一门。
- 列表里点击非选中项 = 设为选中并关闭；点击选中项 = 打开详情。
- 需要持久化到 GRDB（RN 是 `conflictCourseStore` 里的 JSON 数组），带 `studentId`。Phase 2 实现（见 PLAN），Phase 1 先用"组内第一门 + 角标"。
- 注意：RN 只对"课程"做堆叠，考试/假期不参与。

## 7. 其它覆盖层（Phase 2 起，Phase 1 不做，但模型要预留 `kind`）

`ScheduleItem.kind`: `course | exam | holiday | experiment | activity`。

- **物理实验**：课程名含"物理实验"的课程，按顺序一一替换教师和地点为实验接口返回的数据。RN 是按数组下标配对（`phyIdx`），任何一方排序变化都会错配；Swift 端要按 `(week, weekday, begin)` 配对。依赖其它接口，Phase 2 再看。
- **调课**：外部 `https://file.unde.site/GxuToolApp/data.json` 的 `timeShift: [[workDate, restDate]]`。休息日（restDate）的课全部移除；补班日（workDate）显示休息日那天的课，标记 `isShift`（课程块标题前加橙色"(调)"），表头标注：补班日"(补)"、休息日"(休)"。假期块不参与调课。
- **假期**：硬编码日期范围（中秋、国庆、运动会、元旦…），每一天一个全天块（第 1～13 节），只有范围第一天显示标题和"放假"。Swift 端不要硬编码，放进可更新的配置。
- **考试**：由 C 的 FeatureExam 提供；课表层把考试按 `begin..end` 节叠在对应日期上，`kind = exam`。
- **考勤状态**：认证后按 `week-day-begin-end` 匹配给课程块加状态图标，Phase 2。
- **实践课**：`practiceList`，页面下方列表展示（课程名、时间 "1-16周"、教师），不进网格。
- **自定义日程**：`userConfig.activity`，RN 里只在编辑页预览，首页不显示。

## 8. 颜色

- 调色板 `default / macaron / morandi / vivid`，各 15～19 个 hex（见 `colorPalette.ts`）；RN 默认使用 `macaron`（`useBlocksColor` 里 `|| "macaron"`）。iOS 的课程色块要同时适配浅色/深色，所以不直接用这些 hex 的亮度，而是：**取 hex 作为色相/饱和度来源，浅色模式背景用 ~30% 不透明度叠在背景上，深色模式 ~10～20%（RN 的做法：light 0.3、dark 0.1），文字色 = 基色与黑色 1:1 混合**（深色模式 RN 的文字色不够亮，iOS 需要重新校准，保证对比度 ≥ 4.5:1）。这些数值在 GxuDesign 里统一提供。
- 分配算法 `buildColorMap(items, palette, customColors)`：
  1. 只对 `kind == course` 取 key（`title || id`），去重；
  2. 构建邻接图：同一天、`|a.begin - b.end| <= 1 || |b.begin - a.end| <= 1` 视为相邻（**不看周次**）；
  3. 按邻接数降序处理；
  4. 有用户自定义色 → 直接用；否则候选池 = 未被全局使用且非邻居色的颜色，退化为非邻居色，再退化为整个色盘；
  5. 无邻居色 → `pool[abs(hash(key)) % pool.count]`；否则选与邻居色 RGB 欧氏距离最小值最大者。
  6. hash：`h = c + ((h << 5) - h)`，逐字符（UTF-16 code unit）累计，32 位有符号整数溢出语义。**Swift 实现要用 `&<<` / `&+` 和 `Int32`，否则与 RN 配色不一致（不强求一致，但至少要稳定）。**
- 非课程类型默认色：exam 紫、holiday 红、experiment 淡天蓝、activity 橙。
- 自定义颜色按课程名保存（`customColors[courseName]`），Phase 2。

## 9. 课表页 UI 状态与交互（RN 现状）

- 布局：左侧时间列（节次 + 起止时间）、顶部 7 列星期头（`一…日`，`showDate` 时第二行显示 `M-D`，左上角显示月份和"第N周"）。每节高度 80、星期头高 60、课程块边距 2、圆角 5。当 `timeSpanHeight <= 40` 时合并两节显示。
- 今天那一列高亮（主题色 20% 不透明度背景）；当前所处的节次画一条高亮横带（每 5 秒刷新）。**当前时间段判断有 bug**（RN 用上一节结束到本节结束算"当前节"，把课间也算进上一/下一节）；iOS 用精确的"当前时间线"，位置在节次内按分钟线性插值。
- 课程块内容：标题（粗体，最多 5 行）、教室（把 `-` 换成换行，如 `西3-406` → `西3` / `406`）、教师；调课项前缀"(调)"；考勤项带状态图标。
- 体育课地址特殊处理（`CourseDetail.tsx` 与最近提交 44c99e8）：`building + venueName` 含"体育学院"时，只保留第一个"北/西/东"字及之后的部分；并按含"北/西/东"映射到地图关键词（北→行健图书馆行健馆、西→西体育馆、东→东体育馆）。
- 详情内容：课程名称、上课地点（可跳地图）、教师（可查教师信息）、相关考试（按课程名匹配考试）、QQ 群、学分、课程类别、考核方式、选课人数、座位数……点击属性复制到剪贴板。
- 页面状态：
  1. 无教务账号且无缓存 → 展示 `defaultItems` 示例课表（"程序设计基础"等，id 为 `demo-*`）；iOS 改为空状态引导登录，不展示假数据；
  2. 有缓存 → 先显示缓存，后台刷新；
  3. 刷新中 → 标题栏刷新图标；刷新失败 → 保留缓存（RN 只 `console.warn`；iOS 要显示"上次更新于…"的非阻塞提示）；
  4. 学期未开始 / 已结束 → "所有活动已结束，将在 MM月DD日更新至下个学期"（RN 用 `startDay + 20 周`，应改为 `startDay + weekCount`）；
  5. 本周无课 → 空网格（保留时间轴），可加"本周没有课"提示；
  6. `Schedule == null`（后端解析失败）→ 当作错误处理，不覆盖缓存。
- 分页：横向分页 20 页（第 1～20 周），初始页 = 当前周；"回到本周"仅在 `activePage+1 != 当前周` 时出现。iOS 的页数改为 `weekCount`（来自 startDay 接口），且至少覆盖 `weeks` 中的最大值。
- 缓存策略（RN）：成功后整份 `Schedule` JSON 覆盖缓存；若新旧规范化结果 JSON 相同则不触发更新。**RN 缓存不区分账号**——iOS 缓存键必须带 `studentId`（PLAN §3）。

## 10. iOS 侧落地计划（bootstrap 发布后）

ScheduleKit（无 UI 依赖）：
- 模型：`Schedule / TheoryCourse / PracticeCourse / TermStartDay / ScheduleTerm / CourseOccurrence / NextCourses`。
- `ScheduleRepository`：`load(term) -> cached`、`refresh(term)`，GRDB 表 `schedule_snapshot(studentId, year, term, json, updatedAt)`、`term_start_day(studentId?, year, term, day, week, isCurrent)`（学期开始日不含个人数据，可不带 studentId，但课表快照必须带）。迁移 ID：`schedule.v1.createSnapshots`。
- `WeekCalculator`、`ScheduleExpander`（周次展开）、`ConflictDetector`（区间合并）、`NextCourseCalculator`、`CourseColorAssigner`。
- 小组件快照：`SharedKey<WidgetScheduleSnapshot>`，字段对齐 `WidgetScheduleData`（`state/today/tomorrow/next/nextRefreshAt/refreshedAt`）。
- 测试 fixture：先用 `gxu-tool-adapters/adapter-jw/src/schedule/fixture.ts` 的数据手写，标 TODO(verify)，等 A 的 `capture-fixtures.sh` 出真实数据后脱敏替换。

## TODO(verify)

- [ ] `GET /jw/schedule/personal` 的真实响应字段与适配器 `Schedule` 是否完全一致（尤其 `weeks` 是否已是 `number[]`、`practiceList` 的字段名）。
- [ ] `GET /jw/profile/startDay` 返回的 `day` 是 `YYYY-MM-DD` 还是带时区的 ISO 字符串（RN 用 `new Date(day).toISOString()` 存取，疑似带时区）；决定 §2 的解析方式。
- [ ] 学期码：`term=3`（小学期，xqm=16）后端是否支持；RN 的 `toLogicalTerm` 只接受 1/2（以及旧码 3/12），PLAN §3 又定义了逻辑 3 = 小学期，两处含义冲突（RN 把旧教务码 3 映射到逻辑 1）。以 A 的 `AcademicTerm` 实现为准。
- [ ] 第 9/10 节时间重叠（18:55 / 18:45）是否是真实作息，还是 RN 数据笔误。
- [ ] 调课数据 `data.json` 是否继续作为数据源，iOS 是否要接（Phase 2）。
- [ ] 同名同节次课程 id 冲突在真实数据里是否出现。
