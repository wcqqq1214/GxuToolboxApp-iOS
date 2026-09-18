# TimeSchedule 周课表网格

> 组件位置：`src/components/tool/infoQuery/courseSchedule/TimeSchedule.tsx`
> 复用方：主课表 `ScheduleCard`、旧课表页 `CourseScheduleQuery`、班级课表 `ClassCourseSchedule`、日程编辑 `ScheduleEdit`、考勤课表 `AttendanceInfoQueryScreen`（详见「使用方对照」）。

## 它解决什么问题

把「教学周 × 一周 7 天」渲染成一张格子课表：最左列是时间段（`timeSpanList`），其余各列由 `weekdayList` 决定；每列上方是星期表头，下方按时间段排布元素。

组件**不认识课程、考试、节假日或活动**。它只认 `TimeScheduleItemData` 数组：每个数据源自带 `data`，并用 `isItemShow(item, day, week)` 自己回答「我这一项是否属于这一天、这一周」，用 `itemRender` / `stackRender` 决定长什么样。新增一类课表元素 = 往 `scheduleItems` 里加一个数据源，不需要改本组件。

## 设计思路

### 调课 / 调休：方向约定与单向 shiftMap

`shiftRules` 来自远端（见「数据依赖」），每一项是一个二元组 `[补课日, 被补日]`——**前一个是上课的那天，后一个是被替换掉的那天**。方向只看顺序，不看星期几：例如 `["2026-09-20", "2026-09-18"]` 表示 9-20（周日）上 9-18（周五）的课。

组件在 `useMemo`（依赖 `shiftRules`）里把它拆成三个结构：

| 结构        | 类型                  | 用途                                                      |
| ----------- | --------------------- | --------------------------------------------------------- |
| `shiftMap`  | `Map<string, string>` | `补课日 → 被补日`，**单向**，只 `set(workDate, restDate)` |
| `workDates` | `Set<string>`         | 补课日集合，判定列类型与表头 `(补)`                       |
| `restDates` | `Set<string>`         | 调休日集合，判定列类型与表头 `(休)`                       |

由此得到两条语义：

- **补课日列**：参与调课（`needShift !== false`）的数据源改取**被补日**的日期与教学周（`effectiveDay` / `targetWeek`），所以周日那一列显示的是周五的课，冲突合并也按周五那一组算。
- **调休日列**：整列不排课。参与调课的数据源在该列直接 `return null`，只有表头的 `(休)` 还在。

`shiftMap` **不再反向写入**，调休日不去取配对日的元素——旧写法（双向 `shiftMap`，调休日列取配对日课程）正是本次修掉的问题。同目录的 `CanvasSchedule.tsx` 里仍留着那份双向 map，见「已知问题」。

### day / week 为什么是 renderItems 的显式入参

`renderItems(td, tdIndex, keyPrefix, day, week)` 被抽出来，是因为**补课日列要在同一列里渲染两组元素**：

- 主组：`renderItems(td, tdIndex, "main", effectiveDay, targetWeek)`——被补日的元素；
- 附加组：`renderItems(td, tdIndex, "pre", currentDay, currentWeek)`——本列自然日期本来应有的元素，只有 `applyShift && isWorkDay && td.showPreShiftItems` 三者同时成立才渲染。

如果 `day` / `week` 不显式传入、改成在函数里读列变量，第二组就无法用另一套日期和周数跑同一条流程。显式入参是「一份流程渲染两组元素」的实现前提。

配套两点：

- `keyPrefix` 只用于 React key（`${tdIndex}-${keyPrefix}-${gi}`）。两组若共用同一前缀，同一次渲染会产出重复 key。
- 两组各自调用一次 `groupByTimeOverlap`，**冲突栈只在组内合并**，两组之间不会互相吞并。

`renderItems` 定义在组件函数体内，但**不引用组件作用域中的任何变量**——只依赖 5 个入参和模块级的 `groupByTimeOverlap`。这是上面「两组不互相吞并」的结构性保证：它是入参的纯函数，两次调用之间没有共享状态。

`renderItems` 契约：

- **入参**：`td` 数据源；`tdIndex` 该数据源在 `scheduleItems` 中的下标；`keyPrefix` 组别前缀（`"main"` / `"pre"`）；`day` 传给 `isItemShow` / `itemRender` / `stackRender` 的日期；`week` 传给 `isItemShow` / `itemRender` / `stackRender` 的教学周。
- **流程**：`td.isItemShow?.(item, day, week)` 过滤 → `groupByTimeOverlap(..., td.isItemStack, day, week)` 按时段重叠分栈 → 逐栈渲染：单元素走 `td.itemRender(item, day, week)`，多元素走 `td.stackRender(group, day, week, timeRange)`。
- **出参**：渲染出的元素数组（`ReactNode[]`），每个元素自带 key；没有可见元素时是空数组（不是 `null`）。
- **注意**：`timeRange` 由组内各项的 `begin` / `end` 取 `[min, max]`；元素上没有这两个字段时按 `1` 兜底。

> 源码上方那段 `renderItems` 注释的入参列表不全（未提 `week` 也会传给 `itemRender`），且没有出参行。以本节的契约为准。

### 教学周口径唯一来源：getWeekOfDate

`getWeekOfDate(date, startDay)`（`src/features/courseSchedule/utils/weekOfDate.ts`）是「日期 → 教学周」的唯一口径：第 1 周 = 开学日 .. 开学日 + 6 天，之后每满 7 天加 1 周，从 1 开始计数。

被它取代的写法 `Math.ceil(moment.duration(d.diff(startDay)).asWeeks())` 是错的：

- `asWeeks()` 在整周边界返回整数，再 `ceil` 会让每个周首日（周一）**少算一周**；
- 开学当天差值为 0，会被算成**第 0 周**。

本组件里教学周只出现在两处：`props.currentWeek` 缺省时用 `getWeekOfDate(moment(), startDay)` 现算；补课日列用 `getWeekOfDate(effectiveDay, startDay)` 取**被补日**所在周。普通列直接用 `currentWeek`。

### startDay 必须按「天」归一

`startDay` 经 SQLite 链路时来自 `termStartDay.day.toISOString()`，在 UTC+8 下会解析成**当天 08:00**（而非 00:00）。`getWeekOfDate` 内部对两端都做了 `startOf("day")`，所以只要走这个函数，带时分秒的 `startDay` 不会把周首日截到上一周。

本组件自己**不再额外归一** `startDay`（`moment(props.startDay ?? defaultStartDay)`），需要「天」粒度的地方都走 `getWeekOfDate` 或 `format` / `isSame(..., "day")`。给 `TimeSchedule` 传 `startDay` 时不必自己先归一。

### startDay 必须落在 weekdayList[0] 的星期上

每一列的日期是 `startDay + (currentWeek - 1) 周 + index 天`，而列头文字取 `weekdayList[index]`。两者只在 `startDay` 恰好是 `weekdayList[0]` 所代表的那个星期时才对齐——默认 `weekdayList[0]` 是「一」，默认 `startDay`（`"2025-09-08"`）也正是周一。

若传入的 `startDay` 不是那个星期（例如把周四传进来，却仍用周一起头的 `weekdayList`），整张表会整体错位：列头的星期名与列里的日期角标、以及元素实际落入的列三者的关系全部偏移，`(补)` / `(休)` 也会标在与该日期不符的星期列上。传 `startDay` 前先确认它与 `weekdayList` 的起点是同一个星期。

## API

### TimeScheduleProps

```ts
interface TimeScheduleProps<T = any> {
    /** 学期的第一天 */
    startDay?: moment.MomentInput;
    /** 课表当前周，1-20 */
    currentWeek?: number;
    /** 是否显示表头日期，如果不显示日期，左上角显示为周数，否则为第一天所在月份 */
    showDate?: boolean;
    /** 是否显示时间段高亮 */
    showTimeSpanHighlight?: boolean;
    /** 时候高亮今日，通过第一天和周数计算后和系统时间进行比对 */
    showDayHighlight?: boolean;
    scheduleItems: TimeScheduleItemData<T>[];
}
```

| 字段                    | 默认                                                    | 语义与坑                                                                                                                     |
| ----------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `startDay`              | `useUserConfig` 的 `jw.startDay`（默认 `"2025-09-08"`） | 任何 moment 可解析输入。它是全组件唯一的日期基准，传错整张表错位；且必须落在 `weekdayList[0]` 的星期上（见「设计思路」末节） |
| `currentWeek`           | `getWeekOfDate(moment(), startDay)` 现算                | 1 起。分页（pager）场景**必须**由外部逐页传，否则每一页都会算成「本周」                                                      |
| `showDate`              | 假值                                                    | 开启后表头是 `星期(补)\nM-D`；关闭时只有 `星期(补)`                                                                          |
| `showTimeSpanHighlight` | 假值                                                    | 开启后挂一个 5 秒 `setInterval` 刷新 `currentTime`，用于高亮当前时段                                                         |
| `showDayHighlight`      | 假值                                                    | 与系统日期按「天」比对，命中的列整列加深底色                                                                                 |
| `scheduleItems`         | 必填（代码里仍有 `?? []` 兜底）                         | 数据源数组                                                                                                                   |

### TimeScheduleItemData

```ts
interface TimeScheduleItemData<T = any> {
    data: T[];
    itemRender?: (item: T, day: moment.Moment, week: number) => ReactNode;
    isItemShow?: (item: T, day: moment.Moment, week: number) => boolean;
    isItemStack?: (a: T, b: T, ori: T[], day: moment.Moment, week: number) => boolean;
    stackRender?: (items: T[], day: moment.Moment, week: number, timeRange: [number, number]) => ReactNode;
    needShift?: boolean;
    showPreShiftItems?: boolean;
}
```

| 字段                | 默认               | 语义与坑                                                                                                                                                                                                             |
| ------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `data`              | —                  | 元素数据                                                                                                                                                                                                             |
| `itemRender`        | 不渲染内容         | 单元素渲染（不传时外层 `View` 仍在，只是没有内容）。`day` / `week` 是**该组生效的**日期与教学周，补课日列主组拿到的是被补日的                                                                                        |
| `isItemShow`        | **不渲染任何元素** | 判「这一项是否属于这一天」。**不传则该数据源在哪一列都是空的**——`td.data.filter(item => td.isItemShow?.(...))` 里 `?.()` 返回 `undefined` 是假值，会把所有元素滤掉。实际使用时这个字段是必填的，现有调用方全都传了它 |
| `isItemStack`       | 不合并             | 判两项是否同属一个冲突栈。**不同数据源之间从不合并**，只有同一数据源、同一组内才合并                                                                                                                                 |
| `stackRender`       | —                  | 冲突栈渲染。`timeRange` 为 `[min(begin), max(end)]`。组内元素 > 1 个时走它，恰好 1 个时走 `itemRender`                                                                                                               |
| `needShift`         | `true`             | 是否参与调课，见下表                                                                                                                                                                                                 |
| `showPreShiftItems` | `false`            | 补课日列是否追加渲染本列自然日期的元素，见下文                                                                                                                                                                       |

`needShift`：

| 值             | 补课日列                          | 调休日列                     | 普通列                       |
| -------------- | --------------------------------- | ---------------------------- | ---------------------------- |
| `true`（默认） | 主组渲染**被补日**的日期 + 教学周 | 整列 `null`                  | 本列自然日期 + `currentWeek` |
| `false`        | 本列自然日期 + `currentWeek`      | **仍然渲染**（本列自然日期） | 本列自然日期 + `currentWeek` |

`needShift: false` 是节假日标签能继续显示的原因：调休日那一列的课程 / 考试被清空，但节假日标签按自然日期照常出现。

`showPreShiftItems`（默认 `false`）：

- 只在**补课日列**生效，且该数据源还要满足 `needShift !== false`；其他列（含调休日列、普通列）一律不受影响。
- 生效时该列渲染两组：主组（被补日的元素）+ 附加组（本列自然日期 + `currentWeek` 的元素）。两组各自做冲突合并、互不吞并，key 靠 `"main"` / `"pre"` 前缀区分。
- 用途：补课日列默认整列被被补日的元素占满，本列原本排在这一天的元素（例如恰好安排在补课日当天的考试）会被顶掉；开启后两者同时显示。
- 当前**没有任何调用方开启它**（见「已知问题」）。

## 数据依赖

| 来源                                                               | 取什么                                                                                                                      | 缺失 / 失败时的降级                                                                                                                                                   |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `useShift()`（`features/courseSchedule/hooks/detail/useShift.ts`） | `store.shiftRules`                                                                                                          | 初始 `[]`；`init()` 拉远端 `data.json` 的 `timeShift` 失败时**静默保持 `[]`** → 所有列都按普通列渲染                                                                  |
| `useCourseData()`                                                  | `weekdayList`（列数与列序）、`timeSpanList`（时间段）、`theme.timeSpanHeight`、`theme.weekdayHeight`、`courseScheduleStyle` | 有内置默认值（周一~周日、13 个时段）。用 `(weekdayList ?? [])` 兜底：为空时**日期列**网格为空，但左侧时间段栏及其表头照常渲染（`:165-198` 在 `weekdayList.map` 之外） |
| `useUserConfig()`                                                  | `jw.startDay`，仅作 `props.startDay` 的兜底                                                                                 | 取 `IUserConfig` 默认值 `"2025-09-08"`                                                                                                                                |
| `@rneui/themed` 的 `useTheme()`                                    | 今日高亮列的配色                                                                                                            | 无                                                                                                                                                                    |

`shiftRules` 由 `useCourseData().init()` 在启动时一并拉起，`TimeSchedule` 自身不发起任何请求。

`shiftRules` 的元素类型是 `[string, string]`，即 `YYYY-MM-DD` 字符串；组件用 `currentDay.format("YYYY-MM-DD")` 生成同格式的 `dateKey` 去查表。

## 使用方对照

`TimeScheduleView`（同目录）是多数页面的入口包装。它复用 `TimeSchedule` 的全部 props，并额外负责：

- 从 `pageView` 取出 pager 组件，把每个数据源的 `data` 摊平后交给 `buildColorMap` 生成一张配色表，经 `ColorMapContext.Provider` 提供给所有页（`:21-27, 48`）；
- 逐页渲染 `TimeSchedule`，并为每一页传 `currentWeek={index + 1}`（`:61-71`）；
- `initialPage={realCurrentWeek - 1}`，即打开时停在「本周」（`:52`）；
- 给每一页包一层 `Pressable`，长按震动并跳回 `realCurrentWeek`（`:29-32, 64`）；
- 按 `theme.timeSpanHeight` / `theme.weekdayHeight` 计算 pager 自身的高度（`:36-45`）。

**关键差异：它自己算 `startDay = props.startDay ?? moment()`（`:18`）——缺省值是「今天」，不是 `TimeSchedule` 用的 `jw.startDay`。** 而 `realCurrentWeek = getWeekOfDate(moment(), startDay)` 由它算，`initialPage` 与长按「回到本周」都取这个值。

由此产生一处真实失配：`ScheduleEdit` 不传 `startDay`，于是**外层 pager 的 `startDay` 是今天、内层 `TimeSchedule` 的列按 `jw.startDay` 渲染**，两者的「本周」不是同一周（`getWeekOfDate(moment(), moment())` 恒为 1，所以该页的初始页与长按回来都落在第 1 周，而内层网格高亮的周是 `jw.startDay` 口径算出来的）。其余调用方都显式传了 `startDay`，两侧才一致。只有考勤页绕过 `TimeScheduleView` 直接用 `TimeSchedule`。

| 调用方                                                                                                    | 传给 `scheduleItems` 的数据源                                                                                    | `needShift`                                                      | `startDay`                                                                                                                   | 备注                                                                                                                                                                                                                                         |
| --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `features/courseSchedule/components/ScheduleCard.tsx`（主课表，经 `TimeScheduleView`）                    | 4 组：节假日（`useHoliday`）、课程（`useCourse`）、考试（`useExam`）、占位（`defaultItems`），空组被 `filter` 掉 | 节假日显式 `false`；课程显式 `true`；考试与占位不写即默认 `true` | `useStartDay(year, term).startDay`                                                                                           | 每组在 `.map` 里统一补 `isItemShow: item.week === week && item.day === day.isoWeekday()`；课程组带 `isItemStack` / `stackRender`；三个 `show*` 全开                                                                                          |
| `screens/tool/jw/infoQuery/courseSchedule/CourseScheduleQuery.tsx`（旧课表页，经 `TimeScheduleView`）     | 1 组：`normalizeCourse(schedule)`                                                                                | 不写，默认 `true`                                                | `useStartDay(year, term).startDay`（源码注释：不绑全局 `startDay`，随 year/term 动态算）                                     | `isItemShow` 同主课表；不带任何 `show*`                                                                                                                                                                                                      |
| `features/classCourseSchedule/screen/ClassCourseSchedule.tsx`（班级课表，经 `TimeScheduleView`）          | 1 组：`theorySchedule`                                                                                           | 不写，默认 `true`                                                | `useStartDay(+year, term).startDay`                                                                                          | `isItemShow` 同主课表                                                                                                                                                                                                                        |
| `screens/home/schedule/ScheduleEdit.tsx`（日程编辑预览，经 `TimeScheduleView`）                           | 1 组：`activityList`（`IActivity`）                                                                              | 不写，默认 `true`                                                | **不传** → 外层 pager 回退到今天（`moment()`），内层 `TimeSchedule` 回退到 `useUserConfig().jw.startDay`，**两者不是同一周** | `isItemShow` 用 `item.weekday === day.weekday() && week ∈ [weekSpan[0], weekSpan[1]]`。`IActivity.weekday` 是「0-6，周日为 0」，与 moment 默认 locale 下 `day.weekday()` 一致，但与上面几处的 `day.isoWeekday()`（周一为 1）**不是同一口径** |
| `screens/tool/auth/attendanceSystem/AttendanceInfoQueryScreen.tsx`（考勤课表，**直接用 `TimeSchedule`**） | 1 组：`courseList`（`AttendanceCourseClass`）                                                                    | 不写，默认 `true`                                                | `props.calender?.firstWeekBegin`——考勤日历自己的周首日，**与课表 `useStartDay` 不同源**                                      | `currentWeek` 来自手输 `NumberInput`（1-20），不走 pager；`isItemShow` 用 `moment(item._ori.weekDay).isSame(day, "d")`                                                                                                                       |

各组数据源的 `item.week` / `item.day` 由各自的归一函数产出（课程主体走 `normalizeCourse`，考试走 `normalizeExam.ts`），`isItemShow` 只做比对。若某组的周数口径与 `getWeekOfDate` 不一致，症状是该组元素整组落到错误的列或消失。

改组件时的评估面：`showDate` / `showTimeSpanHighlight` / `showDayHighlight` 只有主课表与考勤页开；`needShift` 只有主课表的节假日组显式关掉；`showPreShiftItems` 目前无人开启；`startDay` 只有 `ScheduleEdit` 不传（并因此产生上面那条 `TimeScheduleView` 与 `TimeSchedule` 的周口径失配）。

## 已知问题 / 改进方向

- **`showPreShiftItems` 无调用方**：属性已实现，但全仓库没有任何数据源开启它（`grep showPreShiftItems src/` 只命中类型声明与本组件的读取处）。主课表的考试组因此仍是默认 `false`，补课日当天原本的考试会被顶掉；要修得在调用方显式开启。
- **`ScheduleEdit` 的外层 pager 与内层课表周口径不一致**：`TimeScheduleView` 自己算 `startDay = props.startDay ?? moment()`，而 `ScheduleEdit` 不传 `startDay`，于是 pager 的 `initialPage` / 长按回到的「本周」按「今天」算（恒为第 1 周），内层列的日期按 `jw.startDay` 算。存量行为，非本次引入；修法是让 `ScheduleEdit` 显式传 `startDay`。详见「使用方对照」。
- **旧口径周数计算仍在**：`src/class/jw/course.ts:27`（`getCourseListByDay`）与 `:59`（`atDay`）仍是 `Math.ceil(moment.duration(...).asWeeks()) + 1`。目前这两个方法无调用方（只用到 `getCourseListByWeek`），暂不发作，但应迁到 `getWeekOfDate`。
- **`CanvasSchedule.tsx`（同目录）仍留着本次修掉的同一个问题**：它自建了一份**双向** `shiftMap`，调休日列会去取配对日的课程；`getWeekCourseList` 内还留有 `console.log`。
- **调休日列整列不排课的新语义尚未在旧页面人工复核**：`CourseScheduleQuery`、`ClassCourseSchedule`、`AttendanceInfoQueryScreen` 与主课表共用本组件，行为被一起改掉了，但只对主课表做过核对。
- **测试缺口**：`getWeekOfDate` 有单测；本组件的列渲染分支（补课日 / 调休日 / 附加组）没有单测，目前只有结构性论证，缺人工验证记录。
- **同一天既是补课日又是调休日**：表头按 `(补)` 显示（先判 `workDates`），但参与调课的数据源会因 `isRestDay` 短路而整列不渲染，即「标着补课却空列」。取决于远端 `timeShift` 数据，建议数据侧保证两个集合不相交。
- **左上角月份疑似差一周**：`showDate` 开启时月份取 `startDay.clone().add(currentWeek, "w").month()`，即 `startDay + currentWeek 周`，比各列的 `startDay + (currentWeek - 1) 周` 晚整整一周，而 props 注释写的是「第一天所在月份」。存量行为，非本次引入；跨月的周会显示下一周的月份，改动前先确认是否为刻意取周尾月份。
- **`useShift.ts` 有死代码与失效导入**：`src/features/courseSchedule/hooks/detail/useShift.ts` 从 `@/components/tool/infoQuery/courseSchedule/CourseScheduleTable.tsx` 导入 `ScheduleTableItem`，该文件不存在（`tsc` 未报出）；同文件导出的 `applyShift()` 已无任何调用方（本组件用自己的 `shiftMap`）。
- **每列各建一次 `StyleSheet.create`**：样式对象在 `weekdayList.map` 的列循环内创建，列数有多少就建多少份（默认 7 份），且每次渲染重建。存量问题，非本次引入。
