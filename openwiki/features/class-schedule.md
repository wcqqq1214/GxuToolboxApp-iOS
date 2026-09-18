---
type: feature
title: 班级课表与全校课表
description: 使用 classScheduleApi 和 gxu-tool-adapters/jw 的班级查询、全校实时课表。
tags: [class-schedule, course-schedule, backend, adapter]
---

# 班级课表与全校课表

两类页面共用 `src/features/classCourseSchedule/api/index.ts`、`backendHttp`（`http://api.tool.gxutech.xyz`）和 `gxu-tool-adapters/jw` 类型，所有调用都先经过 `ensureJwAuthenticated()`。

| 方法 | 接口 | 返回 |
|---|---|---|
| `fetchPersonalSchedule(year, term)` | `GET /jw/schedule/personal` | `Schedule \| null` |
| `fetchSchools()` | `GET /jw/schedule/schools` | `School[]` |
| `fetchMajors(grade, school)` | `GET /jw/schedule/majors` | `Major[]` |
| `fetchFullClasses(year, term, school?, major?, grade?)` | `GET /jw/schedule/class-schedules` | `ClassDetail[]` |
| `fetchClassSchedule(year, term, major, grade, classId)` | `GET /jw/schedule/class-schedule` | `Schedule \| null` |

`cleanParams` 会删除空筛选项；“全部”用省略参数表达。调用方传入的 `term` 是 1/2，后端负责转换为 jwxt 的 3/12，不要再次转换。

## 班级查询

`ClassCourseSchedule.tsx` 通过 `useFilter` 做学校 → 专业 → 年级 → 班级级联筛选；`useClassScheduleData` 调 `fetchClassSchedule`，将 `Schedule` 分成 `normalizeCourse(schedule)` 的理论课和 `schedule.practiceList` 的实践课；返回 `null` 显示获取失败。

## 全校实时课表

`FullCourseScreen.tsx` 使用 `SectionList` 按学校/专业/班级展示 `ClassDetail`，按需调用 `fetchClassSchedule`，检查所选周、日、节次是否有覆盖当前时间的标准化课程，并在 `ClassCard` 中显示。单个班级请求失败不会阻塞整页。

旧 `src/js/jw/course.ts` 仍有直连 jwxt 的 `courseApi.getClassCourseSchedule*`，新调用应使用 `classScheduleApi`。

验证：`npx tsc --noEmit`，从工具箱手动进入 `classCourseSchedule` 和 `FullCourseScreen`。
