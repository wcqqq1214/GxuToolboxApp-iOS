---
type: feature
title: 课表（首页）
description: 首页合并理论课、考试、节假日、考勤和物理实验的课表系统。
tags: [course-schedule, home, schedule, features]
---

# 课表（首页）

首页 `ScheduleCard` 消费多个领域 hook，统一输出 `src/features/courseSchedule/type/schedule.ts` 的 `ScheduleTableItem`：`id`、`week`、`day(1-7)`、`begin`、`end`、`title`、`subtitle`、`location`、`teacher`、`color`、`kind`、`status`、`isShift`、`raw`。

| 来源 | 入口 | 缓存 |
|---|---|---|
| 理论课 | `useBaseCourse` → `normalizeCourse` | MMKV `personalSchedule` |
| 考试覆盖 | `useExam` → `normalizeExam` | `originalExamList`、`examStartDay` |
| 考勤覆盖 | `useAttendance` → `normalizeAttendance` | `originalAttendanceList`、`attendanceStartDay` |
| 物理实验补丁 | `usePhyExp` | `originalPhyExpList` |
| 节假日 | `useHoliday` | 硬编码日期 |
| 实践课 | `usePractice` | AsyncStorage `practiceSchedule` |
| 调课 | `useShift`/`applyShift` | 远端 `data.json` 的 `timeShift` |
| 冲突 | `useConflictCourseStore` | 本地状态 |
| 学期起始日 | `useStartDay` | SQLite `termStartDay` |

`useCourse(year, term)` 是组合根：读取起始日，刷新理论课、物理实验、考勤，再向理论课补充实验信息和考勤状态。物理实验按两个列表的顺序配对，不是按 key 匹配；考勤只有认证状态为 `authenticated` 时才覆盖课程。

用户自定义日程由 `ScheduleEdit` 编辑并保存到 `userConfig.activity`，目前只在编辑器预览中显示，首页 `ScheduleCard` 尚未渲染。

## 关键约束

- Zustand 初始化时同步读取 MMKV，首屏先有缓存；网络成功后才替换。
- `normalizeCourse` 只做 adapter `Schedule` 到 UI 模型的字段适配，不负责清洗数据。
- 后端课表调用必须经过 `ensureJwAuthenticated()`；未认证返回 `null`/`[]`，hook 保留旧缓存。
- 周次计算依赖正确的 term start day。当前 `useStartDay` 实际解析全局当前学期，调用方传入的 year/term 会被忽略。

验证：`npx tsc --noEmit`、`pnpm start`，并在真机观察首页课表；解析器证据在 `gxu-tool-adapters` 的 schedule parser test。
