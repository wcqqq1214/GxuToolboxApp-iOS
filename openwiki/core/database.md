---
type: infrastructure
title: 数据库（SQLite + Drizzle）
description: op-sqlite 与 drizzle 的 schema、初始化、迁移、仓储和账号隔离注意事项。
tags: [core, database, sqlite, drizzle]
---

# 数据库（SQLite + Drizzle）

结构化数据使用 SQLite。schema 在 `src/core/schema.ts`，初始化在 `src/core/db.ts`，迁移在 `drizzle/migrations/`。

## 初始化与表

`initDB()` 打开 `gxu_tool.db`，用 drizzle 包装 op-sqlite，并对 `executeRawAsync` 做兼容转换：op-sqlite 17 返回 `{ rawRows, columnNames, rowsAffected }`，drizzle-orm 0.45.2 驱动需要 `Scalar[][]`，因此返回 `res?.rawRows ?? res`。随后执行迁移。

| 表 | 主键 | 用途 | 仓储 |
|---|---|---|---|
| `evaluationTemplates` | `id` 自增 | 评价模板 | `features/evaluation/store/template.ts` |
| `userProfiles` | `studentId` | 用户资料 | `core/repo/userProfileRepo.ts` |
| `termStartDay` | `year + term` | 学期起始日 | `features/courseSchedule/repo/startDay.ts` |
| `examScore` | `id` | 成绩 | `features/examScore/repo/ScoreRepo.ts` |
| `examInfo` | `id + studentId + year + term` | 考试信息 | `features/examInfo/repo/ExamInfoRepo.ts` |
| `selectedCourses` | `studentId + year + term + classId` | 已选课程 | `features/selectedCourse/repo/SelectedCourseRepo.ts` |

## 迁移状态

`drizzle/migrations/migrations.ts` 已注册 `m0000`、`m0001` 和 `m0002`：后两者分别创建 `examInfo` 与 `selectedCourses`。修改 schema 后必须重新生成迁移、提交 SQL 与 snapshot，并同步注册到 `migrations.ts`。

`initDB()` 仍保留一组历史开发期删表逻辑，其中部分 snake_case 名称与 drizzle 的 camelCase 表名不一致；不要把这段逻辑当成正式迁移机制，也不要继续扩展旧删除列表。

## 账号隔离

`examScore` 没有 `studentId`，`scoreRepo.upsert()` 和 `getList()` 只按成绩 id/学年学期过滤，不同账号会共享缓存。`examInfo`、`selectedCourses` 和 `userProfiles` 带账号维度；其中 `SelectedCourseRepo` 的全量替换与学期替换都只删除当前 `studentId` 的目标切片。

## 仓储规则

`userProfileRepo` 按 `studentId` upsert；`ScoreRepo` 负责成绩写入、按条件查询和 `usualScore` 更新；`ExamInfoRepo.replaceByTerm` 用事务执行按学期删除再插入；`SelectedCourseRepo` 按账号与查询范围事务替换，防止退课记录残留；`startDay.ts` 负责后端 `/jw/profile/startDay`、当前学期缓存和同步。评价模板表提供 CRUD，但一键评价仍读 AsyncStorage 的 `@EvaluationTemplate`，存在双路径迁移缺口。

组件中不要写 SQL；多行写入用事务；刷新按维度替换；页面先读本地再请求网络。

## 检查数据库

`pnpm pull-db` 通过 `scripts/pull-db.ps1` 从 debug 包 `com.gxu_tool_app.debug` 拉取 `gxu_tool.db`（及可选 `-wal`/`-shm`）到 `debug-db/`，可用 IDE 打开。
