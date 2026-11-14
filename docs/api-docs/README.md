# 网络接口参考

这里记录 2026-07-31 整理的 RN v2.1.3 beta 接口，文中的 `src/` 路径属于 RN 上游。当前 iOS 请求、认证与响应模型以 [Swift 实现](../../Packages/)和[脱敏样本](../../Fixtures/sanitized/README.md)为准。

| 分篇 | 内容 |
| --- | --- |
| [教务系统](01-教务系统-jwxt.md) | 课表、成绩、选课、个人信息、Web 导出 |
| [统一认证](02-统一认证系统-CA.md) | CAS 登录及服务认证 |
| [辅助系统](04-其他辅助系统.md) | 教师、OA、问卷、实验课、工程训练、ACM、OTA 与辅助链接 |

RN v2.2 对照及后续验证事项见 [iOS 迁移记录](../ios-migration/README.md)。

考勤 v2 的当前契约见 [AttendanceSession](../../Packages/GxuCore/Sources/GxuAuth/AttendanceSession.swift)及对应功能模型。自建后端的公开接口目录为 [Swagger JSON](https://api.tool.gxutech.xyz/docs-json)，iOS 实际使用的响应见[脱敏样本](../../Fixtures/sanitized/README.md)。公开目录不代表所有路由都已通过认证业务验证。

旧考勤协议、自建后端旧说明、考试迁移计划和一次性调研已从当前目录移除，可通过 Git 历史查阅。
