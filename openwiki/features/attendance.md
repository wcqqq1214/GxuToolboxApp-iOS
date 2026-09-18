---
type: feature
title: 考勤数据查询
description: 基于 ykt token 的考勤日历、个人记录、统计和首页课表合并。
tags: [attendance, ykt, course-schedule]
---

# 考勤数据查询

认证说明见[考勤认证](../auth/attendance-auth.md)，本页只说明数据查询和课表覆盖。`src/features/attendance/api/index.ts` 访问 `https://yktuipweb.gxu.edu.cn`，从 `userMgr.attendanceSystem.getLoginRes().data.token` 生成 `Authorization: Token ...`；无 token 时 `getAuthHeaders` 返回 `null`，不会发匿名请求。

## 接口

- `getMenuData()`：`GET /api/account/getIndexData`，参数 `rm=SYS004`；响应 `code === 600` 时写入 `AttendanceSystemMenuData`。
- `calenderData.getList/get/getByTermId/getBySchoolTerm/getCurrent`：查询日历；`getBySchoolTerm(year, term)` 按 `calendarName === \`${year}-${term}\`` 匹配。
- `getPersonalData(termId, page_size, data)`：`POST /api/personalData/getPersonalData`，返回分页 `PageRes<AttendanceData>`。
- `getPersonalDataCount(termId, data)`：`POST /api/personalData/getPersonalDataCount`。
- `getAttendanceTable(week, termId=18)`：`POST /api/rank/selectByStudent`，包装为 `AttendanceCourseScheduleClass`。

## 与首页合并

`useAttendance` 先从 MMKV `originalAttendanceList`、`attendanceStartDay` 恢复，再调用 `attendanceMachine.refreshToken()`。只有认证成功才解析 `getBySchoolTerm(year, term)`、请求 `getPersonalData(calendarId, 1000)` 并更新缓存。`normalizeAttendance` 把 `day`、`periodSplit` 转为 week/day/begin/end，状态写入 `status = atdStateId`。`useCourse` 用 `week-day-begin-end` key 将它覆盖到课程上。

`src/js/auth/attendanceSystem.ts` 仍保存旧查询逻辑，账号页也会使用它；新的登录状态机在 `src/core/auth/attendance`，查询代码在 `features/attendance/api`。

## 页面与验证

路由 `AttendanceInfoQueryScreen` 位于 `src/screens/tool/auth/attendanceSystem/AttendanceInfoQueryScreen.tsx`，状态图标复用 `AttendanceStateIcon`。验证：`npx tsc --noEmit`，并确认未认证初始化不会覆盖 `originalAttendanceList`，标准化后的 week 从 1 开始。
