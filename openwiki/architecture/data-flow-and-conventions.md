---
type: architecture
title: 数据流与约定
description: 外部响应、认证、缓存、错误处理和新旧代码边界。
tags: [数据流, 约定, Zod]
---

# 数据流与约定

标准链路是：

```text
screen/component → hook → feature api/repository → core http/auth/db → 外部系统或 SQLite
```

页面不能直接访问 `http`、`sql`、`cookie` 或 storage。外部响应必须先经过 schema/parser，再转换为稳定内部模型；原始数据若必须保留，应放在 `raw` 或 `raw_json`，不能让 UI 依赖原始字段。

错误处理链是 `api/repository → throw 或 null → hook 的 loading/error/data → screen 一次提示或降级界面`。底层 API 不应弹 Toast，不应在网络失败时清空已有缓存。

SQLite 写入应通过 repository，多行更新使用事务，刷新按来源/学年/学期替换。新函数应有中文契约注释，明确作用、入参、出参和修改注意事项。

`gxu-tool-adapters/jw` 是后端和前端共用的标准化边界，负责 `parseSchedule`、`parseScore`、`parseExam`、`parseSelectedCourseList` 等解析器和稳定类型。`SelectedCourse` 是已选课程的 canonical model；修改这些类型会同时影响 adapter 测试、后端接口、前端仓储和消费页面。
