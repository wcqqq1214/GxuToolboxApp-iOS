# 网络接口参考

本目录整理自 2026-07-31 的 RN v2.1.3 beta 源码，各分篇里的 `src/` 路径指向当时的 RN 上游。iOS 端实际的请求逻辑、认证流程和响应模型，以 [Packages/](../../Packages/) 中的 Swift 源码、[脱敏样本](../../Fixtures/sanitized/README.md)和 [iOS 迁移记录](../ios-migration/README.md)为准。

| 分篇 | 涵盖内容 |
| --- | --- |
| [教务系统](01-教务系统-jwxt.md) | 课表、成绩、选课、个人信息与网页导出 |
| [统一认证](02-统一认证系统-CA.md) | CAS 单点登录及各子系统服务认证 |
| [辅助系统](04-其他辅助系统.md) | 教师查询、OA 文件、问卷、物理实验、工程训练与版本更新 |

考勤 v2 的当前契约见 [AttendanceSession](../../Packages/GxuCore/Sources/GxuAuth/AttendanceSession.swift) 及对应功能模型；自建代理后端的公开接口目录见 [Swagger JSON](https://api.tool.gxutech.xyz/docs-json)（公开列出不代表全部路由已通过认证态实测）。
