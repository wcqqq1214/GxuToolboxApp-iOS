---
type: feature
title: 考试成绩与 GPA
description: 通过后端查询考试成绩、平时成绩并写入 examScore，同时提供 GPA 计算器。
tags: [exams, exam-score, database, gpa]
---

# 考试成绩与 GPA

## 接口

`src/features/examScore/api/index.ts`：

- `exam.remote(year, term, page, limit)`：认证后 `GET /jw/score`，传 `pageSize`、`pageNo`、`orderBy`、`order`，返回 `ApiResponse<ScoreData>`。
- `usual.remote(year, term, id)`：`GET /jw/score/usual` 查询某门课平时成绩。
- 未认证时两者都返回 `null`；`getExamScore` 是 `limit = 1000` 的便捷封装。

## 数据库与 hook

`examScore` 以 `id` 为主键，保存 year/term/courseName/credit/score/teacherName/uploadAt/usualScore/updatedAt。`scoreRepo.upsert` 是逐行 select 后 insert/update 的循环，不是事务或批量 upsert，中途失败会留下已写入的前半部分；`getList(year?, term?)` 动态过滤；`updateUsualScore` 只更新平时成绩列。

`useScore(year, term)` 封装完整的本地优先流程：先按逻辑学期 1/2 读取 `scoreRepo`，再静默刷新 `/jw/score`，用请求版本号阻止旧请求覆盖新学期状态。它同时调用 `useSelectedCourses` 读取同学期已选课程，以 `SelectedCourse.classId` 和 `ScoreRepo.id` 的差集生成 `notScore`，页面不再编排 `loadLocal/fetchRemote`。每次远端刷新把 `updated_at` 统一为 Unix 秒级时间戳，读取时兼容旧毫秒缓存。

`useUsualScore` 按内存详情 → SQLite 中可解析的 JSON → `/jw/score/usual` 的顺序读取。路由 `examScore` 对应成绩表，`gpaCalculator` 对应 GPA 页面。

## GPA 与已知缺陷

`src/hooks/useGpa.ts` 按课程计算 `point = score / 10 - 5`，只有 `score >= 60` 计入分子，最后按总学分计算。当前实现和注释都表明页面暂时展示加权平均分，不应把它当作已完成的正式 GPA 规则。

`examScore` 没有 `studentId`，是全局缓存；切换账号可能看到上一个账号的成绩，修复需要把 studentId 加入表和查询条件。已选课程缓存已经按 `studentId` 隔离，不能据此误认为成绩缓存也已完成多账号隔离。

验证：`npx tsc --noEmit`；`scoreRepo.upsert` 的最低行为要求是同一 id 重复写入不产生重复行。
