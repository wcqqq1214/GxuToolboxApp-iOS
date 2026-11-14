# RN v2.2 与 iOS 的对齐状态

核对日期为 2026-11-15。RN 基准为 `origin/v2.2` 的 `774f47a8`，iOS 功能基准为 `77f2e2a6`。本表替代 2026-11-06 的迁移分工表，描述当前源码和本次接口探测，不代表所有功能均完成真机验收。

## 尚未对齐的功能

| 功能 | RN 当前实现 | iOS 当前状态 | 接入条件 |
| --- | --- | --- | --- |
| 调课信息总览 | `RescheduleNotificationScreen` 调用 `jwxt.getReschedulingNews`，向学校 `/xtgl/index_cxDbsy.html?doType=query` POST 查询已读、未读通知 | 工具箱没有总览入口；单门课程调课详情已通过 `/jw/schedule/personal/reschedules` 接入，不能当作总览替代 | 后端提供总览查询契约并验证响应；不能把按教学班查询接口当作全量通知接口 |
| 选课课程列表 | `courseApi.courseSelection.getList` 向学校 `/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html` POST 查询，带课程类别、分页、关键词及写死的 `xkkz_id` | 无对应入口；已选课程和校选课查漏是不同功能 | 后端提供可用的选课批次及列表查询契约，不复制 RN 写死的选课批次 |
| 完整期末评教 | 总览页面仍调用教务直连；API 文件定义了 `/jw/evaluation` 代理方法，但当前没有页面调用；详情、保存、提交使用学校 `/xspjgl/` 接口 | 工具箱保留不可用入口；已有总览和本地模板代码，没有详情填写、保存、提交或批量评教闭环 | 先恢复总览代理，再提供详情、保存和提交契约；仅总览可用也不能宣称完整评教可用 |

入口以 [ToolboxCatalog](../../App/Shell/ToolboxCatalog.swift) 为准，评教已有实现见 [EvaluationViews](../../Packages/FeatureCourse/Sources/FeatureCourse/Evaluation/EvaluationViews.swift)。遵循现有迁移决定，暂不另行实现教务直连绕过代理。

## 2026-11-15 后端实测

对 `https://api.tool.gxutech.xyz` 发起未登录 GET 请求。只记录状态和通用错误信息，不提交评教或修改学校数据。

| 路径 | HTTP | 结果及解释 |
| --- | --- | --- |
| `/jw/evaluation` | 404 | `Cannot GET /jw/evaluation`；这是 RN API 文件定义、iOS 总览代码使用的代理路径 |
| `/jw/schedule/adjust`、`/jw/timeShift`、`/jw/rescheduling` | 404 | 均返回对应的 `Cannot GET`；这些是历史候选路径，不是已确认的代理契约 |
| `/jw/courseSelection`、`/jw/course-selection` | 404 | 均返回对应的 `Cannot GET`；这些是历史候选路径，不是已确认的代理契约 |
| `/docs-json` | 200 | 公开 OpenAPI 目录含 65 条路径；未发现评教、调课总览或选课课程列表代理，单课调课路径为 `/jw/schedule/personal/reschedules` |
| `/openapi.json`、`/api-json`、`/swagger-json` | 404 | 这些常见地址不提供目录；实际目录为 `/docs-json` |
| `/jw/profile/startDay` | 200 | 响应 `code: 200`、`message: success`，作为同一后端可达性的对照 |

本次没有本地 `.secrets/account.env`，未做登录后的业务请求。404 只能证明上述方法和路径本次不可用，不能证明不存在其他未公开路径，也不能排除认证相关的路由差异。最新 RN 未提供调课总览和选课列表的新代理契约，因此本轮没有可确认可用并接入的新增功能。后续拿到正式契约或部署信息后，应重新进行认证读取验证。

## 已有对应实现

以下项目不再列为缺失。这里确认的是源码实现，不替代真实账号联调。

| 项目 | 当前 iOS 实现 |
| --- | --- |
| 空闲教室 | 时间查询、教室查询、楼栋楼层选择、周缓存和冷却控制，位于 `FeatureCampus/EmptyClassroom` |
| 考勤 v2 | `/attendance/v2/captcha`、`/attendance/v2/login` 已接入，位于 `GxuAuth/AttendanceSession.swift` |
| 校选课查漏 | 请求 `/jw/elective-progress`，校验账号并隔离缓存，位于 `FeatureCourse/ElectiveStrategy` |
| 本科生提示 | 教务账号页已显示本科生使用范围与研究生课表提示 |
| 单门课程调课详情 | `/jw/schedule/personal/reschedules` 及课程详情调课区域已实现 |
| 全部反馈和我的反馈 | `/feedback/public`、`/feedback/mine/{学号}`，支持分页、个人列表登录提示及切账号清空 |
| 考试详情 | 类别、状态、待定考场或座位提示和复制考试信息已实现 |

## 保留的差异与待验证事项

- RN 暂时隐藏了分享课表，iOS 仍保留本周课表分享，不属于 iOS 缺失功能。
- iOS 使用原生界面、GRDB 和 WidgetKit，不移植 RN 组件、数据库迁移、Android 小部件及 OTA 流水线。
- 校选课小学期映射曾出现 `/jw/elective-progress` 的 `term=3` 与 `/jw/score` 的 `term=0` 不一致。iOS 保留 `ElectiveReviewResolver` 按课程名、学分、学年和对应学期唯一匹配的核对逻辑。本次没有真实账号响应，尚未确认后端是否已修复。
- 真实账号、校园网、iOS 18、辅助功能与小组件共享等未覆盖范围见[迁移索引](README.md)及[设备检查清单](device-checklist.md)。
