---
type: feature
title: 选课与校选课查漏
description: 检查校选课完成情况，并查询已经选中的课程。
tags: [选课, 校选课, 教务]
---

# 选课与校选课查漏

## 校选课查漏

`src/features/electiveStrategy/hooks/useElectiveStrategyData.ts` 是页面的统一数据入口。它通过 `useSelectedCourses({kind: "all"})` 先读当前账号的 SQLite 缓存，再静默刷新 `/jw/selected-courses`；随后筛选 `selectionType === "通识选修课"`。成绩同样先读 `scoreRepo`，再用 `/jw/score` 刷新，只有及格课程会进入培养方案统计。个人信息读取失败时使用 2025 级方案降级，课程或成绩完全不可用时向页面返回明确错误。

旧的 `electiveStrategy/api` 直连教务实现及其本地 Zod schema 已删除。校选课与考试成绩页现在共同消费 adapter 的 canonical `SelectedCourse`，页面不再理解 `kcmc`、`jxb_id` 等教务原始字段。

`utils/class2021..2025.ts` 提供不同年级的毕业策略，`utils/index.ts` 的 `getStrategy(grade)` 负责选择策略，找不到时回退到 2024 策略。页面是 `screen/ElectiveStrategy.tsx`。

## 已选课程

`src/features/selectedCourse/api/index.ts` 的 `selectedCourseApi.getList(scope)` 调用 `GET /jw/selected-courses`。`scope` 可以是全部历史，也可以是明确的 `year + term`；term 使用逻辑码 1/2，由后端转换为教务系统的 3/12。`SelectedCourseRepo` 按 `studentId` 隔离缓存，全量刷新只替换当前账号，学期刷新只替换当前账号的对应学期。`useSelectedCourses(scope)` 对页面只暴露 `courses/loading/refreshing/error/refresh`，缓存与同步顺序由 hook 内部负责。

旧的 `CourseSelectionList.tsx` 和 `SelfCourseSelection.tsx` 仍走 `src/js` 选课接口，它们处理的是选课操作/可选课程，不等同于这里的已选课程查询。
