---
type: reference
title: 应用类型
description: 应用领域类型的位置，以及外部 adapter 类型如何进入内部模型。
tags: [type, contract, api, schema]
---

# 应用类型

类型分为仓库维护的应用类型和 `gxu-tool-adapters` git 依赖提供的解析器类型，共同构成外部不可信数据与内部模型之间的边界。

## 目录

- `src/type/global.ts`：`SchoolTerms`、`SchoolLabel`、`SchoolValue`、`PageModel`、`QueryModel`、`QueryDate`、`UserModel`、`ScheduleClassInfo` 以及查询/日期 Zod schema。
- `src/type/IUserConfig.ts`：`IUserConfig`、`IUserJwConfig`、`IUserPreference`、`IUserTheme` 和 `defaultUserConfig`，驱动主题、学年学期、课表编辑和偏好页。
- `src/type/infoQuery/`：JW 领域的基础、课程、考试和成绩原始类型。
- `src/type/api/`：后端、考勤、班级课表、考试、文件、评价、教师信息等接口包装类型。
- `src/type/app/activity.ts`、`src/type/pos.ts`：活动首页和 POS/订单类型。

## 外部到内部的契约

`gxu-tool-adapters/jw` 导出：

- `parseSchedule`、`parseClassInfo`、`parseMajor`、`parseClassDetail` → `Schedule`、`OriginalSchedule`、`ClassInfo`、`Major`、`School`、`ClassDetail`。
- `parseScore`、`parseUsualScore` → `Score`、`UsualScore`、`OriginalScore`。
- `parseExam` → `Exam`。
- `parseCourse` → `Course`。

新功能直接把 adapter 类型作为后端解析结果与 UI 之间的契约；旧路径仍在 `src/type/infoQuery` 描述原始 JW payload。

## 约定与所有权

`jg_id`、`zymc`、`xnm`、`xqm` 等中文拼音字段必须保留，它们对应原始 JW API。自建后端通常包装为 `{ code, message, data }`，考勤使用自己的 `ResRoot<T>`。用户可编辑的查询/日期输入应使用 `global.ts` 中与类型相邻的 Zod schema。

业务类型放在 `src/type/api/<domain>` 或 `src/type/infoQuery/<domain>`；adapter 在仓库外维护，不能直接改 node_modules 中的代码，解析器变化需更新 `package.json` 版本后重新安装。
