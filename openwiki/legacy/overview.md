---
type: reference
title: 遗留代码总览
description: 遗留源码区域、仍在使用它们的调用方，以及渐进迁移计划。
tags: [legacy, migration, technical-debt]
---

# 遗留代码总览

项目处于迁移中。新代码应放入 `src/features/` 和 `src/core/`；其余区域只有在维护旧页面时才触碰。

## 遗留区域

| 区域 | 内容 | 状态 |
|---|---|---|
| `src/screens/` | `MainTab.tsx`、`Root.tsx`、`WebViewScreen.tsx`、`home/`、`setting/`、`tool/` | 仍大量使用，导航入口在此 |
| `src/js/` | 旧业务层：认证、HTML parser、信息、JW、账号管理、课表、权限等 | 部分权威，部分已废弃 |
| `src/class/` | `BaseClass`、JW、考勤包装类 | 考勤和成绩仍使用 |
| `src/type/` | global、IUserConfig、api、infoQuery、app、pos | 许多 API 的内部契约 |
| `src/api/schema/` | 旧 schema 片段 | 已被 feature 内 Zod 取代 |

## `src/class` 包装层

这不是孤儿代码：`class.ts` 提供 `BaseClass<T>` 和带 Zod 转换的 `BaseZodClass<S,O>`；`jw/course.ts` 提供 `CourseClass`/`CourseScheduleClass`；`jw/exam.ts` 提供 `ExamInfoClass`；`auth/attendanceSystem.ts` 提供考勤数据、课程和时间匹配包装。它们被 `ScheduleCard`、课程详情/冲突组件、`useCourse`、`usePhyExp`、考试详情和考勤页面等使用。替换时必须保留周次、星期和考勤时间段匹配行为，不能盲目迁移。

## 仍在引用遗留代码

- `src/js/jw/jwxt.ts` 仍被调课通知页面和通知 API 使用。
- `src/js/auth/auth.ts`（`authApi`）是 `unifiedAdapter` 的实现。
- `src/js/jw/course.ts` 的 `courseApi.getCourseSchedule(year, term)` 已经认证后请求后端 `/jw/schedule/personal`，与新 `classScheduleApi.fetchPersonalSchedule` 使用同一接口，但仍用 AsyncStorage 的 `courseScheduleStore`/`courseScheduleSetting`；新链路使用 MMKV `personalSchedule`。`getClassCourseScheduleList` 仍直连 jwxt `/kbdy/bjkbdy_cxBjkbdyTjkbList.html`。
- `src/js/jw/exam.ts` 仍直连 jwxt：`getExamInfo` → `/kwgl/kscx_cxXsksxxIndex.html?doType=query`，`getExamScore` → `/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005`，`getUsualScore` → `/cjcx/cjcx_cxCjxqGjh.html?gnmkdm=N305005`。新考试功能改走 `backendHttp` 的 `/jw/exam`、`/jw/score`。
- `src/js/mgr/user.ts`（`userMgr`）是三套认证状态机共用的账号键值层；教师查询、POS 和 OA API 也仍在旧目录。
- `src/core/user/profile.ts` 将 `JwAuthClient.getUserInfo()` 保存到 `userInfo`，现代路径是 `userProfileRepo` + `syncInfo`。
- 小组件 `src/js/nextCourses.ts` 和设置页仍读没有写入方的 AsyncStorage `courseRes`；新链路写 MMKV `personalSchedule`。`widget-task-handler.tsx` 还保留了使用 `getWidgetData` 和 `store.load("courseRes")` 的大段注释旧实现。
- 三套密码加密不能随意合并：JW 使用 `rasPassword.js` 的 `getEncryptedPassword`，CA 使用 `src/js/authRSA.ts` 对反转密码执行 `RSAUtils.encryptedString`，考勤使用 CryptoJS AES-ECB/Pkcs7。

## 迁移优先级

- P0：不再新增遗留文件，新领域代码放入 `features/` + `core/`。
- P1：把 JW/课程/成绩/考试/评价的直连 HTTP 置于 `backendHttp` 和 adapter parser 后（课表、成绩、考试、评价、选课已大部分完成）。
- P2：淘汰 `src/js/jw/jwxt.ts`，剩余调用方是调课通知。
- P3：把 `authApi`、`attendanceAuthApi`、`JwAuthClient` 合并到 `core/auth` adapter。
- P4：把 `src/type` 迁移为 feature 本地 Zod schema，`src/api/schema` 已被取代。
- P5：将剩余页面迁出 `src/screens`；迁移完成前保留 `Root.tsx`/`MainTab.tsx` 作为导航壳。

## 孤立模块

- `src/core/user/profile.ts` 是旧 `userInfo` 存储桥。
- `src/features/notification/api/index.ts` 的 `getNotifications` 引用了未定义的 `reg`，真正逻辑在 `RescheduleNotificationScreen.tsx`。

相关：[数据流与约定](../architecture/data-flow-and-conventions.md)。
