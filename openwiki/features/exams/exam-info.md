---
type: feature
title: 考试信息
description: 通过 /jw/exam 查询考试时间、地点、座位和状态，并按学生隔离本地缓存。
tags: [exams, exam-info, database, backend]
---

# 考试信息

## 接口与标准化

`src/features/examInfo/api/index.ts` 的 `getExamInfo(year, term)` 调用 `backendHttp.get("/jw/exam", {params: {year, term}})`，后端返回 `gxu-tool-adapters/jw` 的 `Exam[]`。客户端对每项执行 `parseExamTime(r.time)`，计算动态 `date`、`status`，并写入 Unix 秒级 `updatedAt`；没有 seat 时归一化为空字符串；后端 data 为 `null` 时原样返回。

`date` 和 `status` 不写入数据库，读取时 `useExamInfo.toExamWithMeta` 重新按 `time` 计算，因此考试结束后状态无需刷新也能变化。

## 仓储与账号隔离

`examInfo` 表主键为 `(id, studentId, year, term)`。`examInfoRepo.getList` 始终要求 `studentId`，空 year/term 表示不加该条件；`replaceByTerm(studentId, year, term, items)` 在事务中先删该学期切片，再插入新数据，取消的考试不会残留。

`ExamInfo.tsx` 通过 `useExamInfo` 先读数据库，再静默请求网络，并从当前 JW 账号取得 studentId。远端明确返回空数据时，hook 也会用空集合替换该学期缓存，避免已取消考试残留。首页课表的 `useExam` 是另一条旧链路：调用 `src/js/jw/exam.ts`、写 MMKV，不要把两条路径混为一谈。

页面：`examInfo` → `src/features/examInfo/screens/ExamInfo.tsx`，卡片在 `components`。验证：`npx tsc --noEmit`，并确认 replace 后指定学期只剩新插入的行。
