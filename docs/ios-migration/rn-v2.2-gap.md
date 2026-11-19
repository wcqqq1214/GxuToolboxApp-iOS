# RN v2.2 与 iOS 对齐状态

2026-11-15 核对时，RN 基准为 `origin/v2.2` 的 `233c3ca1`，iOS 基准为 `638fece0`；2026-11-17 对照 RN `bea9b6c1` 后，iOS 同步补上了转专业前的学年选择和物理实验课表更新。文中日期按北京时间（UTC+8）记录。

## RN 上游动态

2026-11-15 拉取 GitLab 上游后，`origin/v2.2` 从 `774f47a8` 推进到 `233c3ca1`（`origin/main` 仍停在 `c6693990`，GitHub `upstream/v2.2` 停在 `0f54a4c1`，版本号为 `2.2.0` / `20200`，暂未核实线上 APK 或 OTA）：

- [`ab9d701d`](https://gitlab.unde.site/gxutool/gxu_tool_app/-/commit/ab9d701dcf1351da69964ea50203dc4ab181cdf4)：教务学号改为 2/4/4 分格输入，十位学号第 5、6 位为 `30`、`39`、`59` 时弹一次疑似研究生提示，并抽出登录说明卡片。iOS 已有本科生适用范围固定说明，暂未加学号弹窗，也不打算搬运分格输入组件。
- [`233c3ca1`](https://gitlab.unde.site/gxutool/gxu_tool_app/-/commit/233c3ca106d7d48c417fb1a1c200a3e7414315c8)：仅涉及 Android 与 RN OTA 发布脚本及适配器开发依赖升级，不影响 Swift 构建流程。

## 尚未对齐的功能

| 功能 | RN 当前实现 | iOS 当前状态 | 补齐条件 |
| --- | --- | --- | --- |
| 按学号提示疑似研究生 | 十位学号第 5、6 位命中 `30`、`39`、`59` 时提示本科生与研究生教务系统分离，关闭后仍可尝试登录 | 只展示固定说明文字，没有按学号弹窗 | 核实学号编码规则与真实需求；即使加上提示也不能据此拦截登录 |
| 调课信息总览 | `RescheduleNotificationScreen` 向学校 `/xtgl/index_cxDbsy.html?doType=query` POST 查询已读和未读通知 | 暂无总览入口（单课详情已接入 `/jw/schedule/personal/reschedules`，并非全量通知接口） | 等待后端提供总览查询契约并验证响应 |
| 选课课程列表 | `courseApi.courseSelection.getList` 向学校 `/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html` POST 查询，携带写死的 `xkkz_id` | 暂无入口（已选课程和校选课查漏属于其他功能） | 等待后端提供选课批次与列表契约，不复制写死的选课批次 ID |
| 完整期末评教 | 总览仍在直连教务（API 文件有未调用的 `/jw/evaluation` 代理定义），详情、保存、提交走学校 `/xspjgl/` | 工具箱标为「即将上线」；已有总览和本地模板界面，缺少详情填写、保存、提交与批量评教 | 先等总览代理恢复，再补齐详情、保存和提交契约；光有总览还不算可用 |

工具箱入口以 [ToolboxCatalog](../../App/Shell/ToolboxCatalog.swift) 为准，评教界面见 [EvaluationViews](../../Packages/FeatureCourse/Sources/FeatureCourse/Evaluation/EvaluationViews.swift)。按目前迁移策略，暂不绕过代理直连教务评教或选课接口。

## 2026-11-15 后端实测

下面是 2026-11-15 对 `https://api.tool.gxutech.xyz` 的未登录 GET 探测结果（无 `.secrets/account.env`，未测登录态，也未改动学校数据）：

| 路径 | HTTP | 返回结果与说明 |
| --- | --- | --- |
| `/jw/evaluation` | 404 | `Cannot GET /jw/evaluation`，为 RN API 与 iOS 评教总览预期的代理路径 |
| `/jw/schedule/adjust`、`/jw/timeShift`、`/jw/rescheduling` | 404 | 均返回对应 `Cannot GET`，属历史猜测路径 |
| `/jw/courseSelection`、`/jw/course-selection` | 404 | 均返回对应 `Cannot GET`，非已确认代理接口 |
| `/docs-json` | 200 | 公开 OpenAPI 目录含 65 条路径，无评教、调课总览和选课列表；单课调课为 `/jw/schedule/personal/reschedules` |
| `/openapi.json`、`/api-json`、`/swagger-json` | 404 | 实际目录入口为 `/docs-json` |
| `/jw/profile/startDay` | 200 | 返回 `code: 200`、`message: success`，确认后端可达 |

404 只说明上述路径当时在未登录 GET 下不可用，尚无法排除认证态路由差异或未公开接口；结合 RN 提交改过的文件来看，也未新增调课总览和选课列表的代理契约。拿到正式接口文档或部署确认后需用真实账号复测。

## 保留的差异与待验证

- **原生形态差异**：RN 目前隐藏了分享课表，iOS 保留本周课表分享和图片导出；暂未做整张课表批量写入系统日历。iOS 基于原生控件、GRDB 和 WidgetKit 实现，不移植 RN 组件、RN 数据库迁移、Android 小组件及 OTA 流水线。
- **校选课小学期映射**：曾出现 `/jw/elective-progress` 的 `term=3` 与 `/jw/score` 的 `term=0` 不一致，iOS 通过 `ElectiveReviewResolver` 按课程名、学分、学年和对应学期唯一匹配；尚未用真实账号确认后端是否已修复。
- **未覆盖验证项**：真实账号、校园网、iOS 18、辅助功能和小组件共享见[迁移记录](README.md)与[设备检查清单](device-checklist.md)。
