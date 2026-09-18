---
type: quickstart
title: 快速开始：西大工具箱（gxu_tool_app）
description: Android-only React Native 校园工具箱的文档入口、关键概念、目录和修改路由。
tags: [quickstart, overview, react-native, android, gxu-tool]
---

# 快速开始：西大工具箱（gxu_tool_app）

本项目是面向广西大学的 Android-only React Native 0.84 + React 19 + TypeScript 5.9 校园工具箱，聚合教务（jwxt）、统一认证/CA、考勤/ykt、OA 文件、物理实验、工程训练和教师信息等系统。外部数据先经过 adapter 与 Zod 校验，再转为稳定的本地模型供页面和桌面小组件使用。

> 核心链路：从不可信外部系统获取 → Zod 校验 → 转换为稳定模型 → UI/小组件消费。

仓库没有完整的 in-repo 测试套件；常规验证是 `npx tsc --noEmit`、Metro bundle 和真机流程。解析器测试位于 `gxu-tool-adapters` 依赖中。

## 文档地图

| 区域 | 内容 |
|---|---|
| [架构](architecture/overview.md) | 启动顺序、导航、数据流、外部系统、构建工具 |
| [核心基础设施](core/index.md) | HTTP 客户端、SQLite/Drizzle、存储、OTA、类型 |
| [认证](auth/overview.md) | JW、统一 CA、考勤认证和账号存储 |
| [功能](features/index.md) | 课表、考试成绩、评价、考勤、文件、反馈、选课、个人信息等 |
| [UI](ui/index.md) | un-ui 组件库和主题系统 |
| [小组件](widget/overview.md) | Android 桌面课表小组件全链路 |
| [原生 Android](android/native-android.md) | Manifest、服务、OTA、文件打开桥 |
| [遗留代码](legacy/overview.md) | `src/js`、`src/class`、`src/type`、`src/screens`、`src/api` 的现状 |

## 关键概念

- **适配边界**：`gxu-tool-adapters/jw` 提供 `parseSchedule`、`parseScore`、`parseExam`、`parseCourse` 及对应类型；不要把原始教务字段直接暴露给 UI。
- **认证状态机**：`src/core/auth/createAuthCore.ts` 统一 JW、CA、考勤三套状态；状态为 `no_account` → `has_account_not_authenticated` → `authenticated`，刷新使用 single-flight。
- **数据库迁移缺口**：`src/core/schema.ts` 有 5 张表，但 `drizzle/migrations/migrations.ts` 只注册 `m0000`，`examInfo` 的 `0001` 在新库不会执行。
- **账号隔离缺陷**：`examScore` 没有 `studentId`，不同账号的成绩缓存可能互相覆盖；`examInfo` 和 `userProfiles` 使用账号维度。
- **小组件死 key**：小组件仍读 AsyncStorage 的 `courseRes`，新课表写入 MMKV 的 `personalSchedule`。
- **OTA**：`scripts/gen-ota-info.ts` 生成版本信息，原生通过 `ota_version` 校验 bundle 所属 APK 版本。
- **启动顺序**：OTA 清理与数据库初始化并行；`initDB()` 是数据库任务的前置条件，评价模板迁移仍有未等待的 check-then-insert 竞态。

## 修改路由

| 修改意图 | 先读 | 主要入口 | 最小验证 |
|---|---|---|---|
| 新增工具/功能 | [数据流](architecture/data-flow-and-conventions.md) | `src/features/*`、`ToolboxStack.tsx` | `npx tsc --noEmit`、真机流程 |
| 修改课表 | [课表数据层](features/course-schedule/data-layer.md) | `useCourses.ts`、`useBaseCourse.ts`、`normalizeCourse.ts` | 类型检查、首页课表 |
| 修改认证 | [认证总览](auth/overview.md) | `src/core/auth/*` | 三类账号手动登录 |
| 修改考试/成绩/GPA | [考试信息](features/exams/exam-info.md)、[成绩](features/exams/exam-score.md) | `features/examInfo/*`、`features/examScore/*` | 类型检查、设备端缓存检查 |
| 修改评价批量流程 | [评价](features/evaluation.md) | `features/evaluation/api`、`EvaReducer`、`useEvaluationActions` | 类型检查、批量提交 |
| 修改 SQLite | [数据库](core/database.md) | `schema.ts`、`db.ts`、`migrations.ts` | 新增并注册 migration |
| 修改存储 key | [存储](core/storage.md) | `src/core/store.ts`、`src/store/mmkv.ts` | 清数据、重新登录 |
| 修改 OTA/构建 | [OTA](core/ota.md)、[构建](architecture/build-and-tooling.md) | `ota.ts`、`gen-ota-info.ts`、`MainApplication.kt` | `pnpm build-ota`、旧 APK 升级 |
| 修改小组件 | [小组件](widget/overview.md) | `src/widget/*`、`nextCourses.ts`、原生 service | 添加小组件、刷新、观察 tick |
| 修改路由/主题 | [启动导航](architecture/startup-and-navigation.md)、[主题](ui/theming.md) | `src/route/*`、`theme.ts` | 类型检查、真机/明暗主题 |

## 已知边界

iOS 目录只是脚手架；`login-proxy.md` 是未完全落地的设计文档；`src/js/be.ts` 的 ACM axios 客户端尚未接入业务；`.github/` 中的 OpenWiki workflow 属于文档基础设施。本批改写只处理文档，不扩大这些范围。
