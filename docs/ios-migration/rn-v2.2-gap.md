# RN v2.2 与 iOS 的对齐状态

核对日期为 2026-11-15，按 Asia/Taipei（UTC+08:00）计算。RN 基准为 `origin/v2.2` 的 `233c3ca1`，iOS 功能基准为 `638fece0`。本表替代 2026-11-06 的迁移分工表，描述当前源码；后端探测结果另列日期，不代表所有功能均完成真机验收。

## RN 上游更新

2026-11-15 拉取 GitLab 上游后，`origin/v2.2` 从 `774f47a8` 前进至 `233c3ca1`，新增以下两条提交。两条提交的提交者时间均为当天 21:09:57，作者时间均为 11 月 14 日；提交时间不等于 OTA 上线时间。

| 提交 | 源码变化 | 对原生 iOS 的影响 |
| --- | --- | --- |
| [`ab9d701d`](https://gitlab.unde.site/gxutool/gxu_tool_app/-/commit/ab9d701dcf1351da69964ea50203dc4ab181cdf4) | 教务学号改为十位分格输入，按 2/4/4 分组；十位学号第 5、6 位为 `30`、`39`、`59` 时，在本次页面生命周期内弹出一次疑似研究生提示；抽取登录说明卡片 | iOS 已有本科生适用范围与研究生课表的固定说明，尚无学号识别弹窗；不需要照搬 RN 输入组件 |
| [`233c3ca1`](https://gitlab.unde.site/gxutool/gxu_tool_app/-/commit/233c3ca106d7d48c417fb1a1c200a3e7414315c8) | OTA 有有效底包提交时检查累计差异，旧底包未记录提交时使用 MR/push 比较基线；仅移除 Android `versionName` 的 beta 后缀可放行；适配器开发依赖由 1.1.1 升至 1.2.1，并移除重复的运行时依赖 | 属于 RN/Android 发布链，不移植到 Swift 构建流程；本轮未审计适配器发布包内容 |

本次拉取时，GitLab `origin/main` 仍为 11 月 11 日的 `c6693990`，上述变更尚未合入该分支；GitHub 原项目的 `upstream/v2.2` 仍为 10 月 28 日的 `0f54a4c1`。RN 源码版本仍是 `2.2.0`、构建号 `20200`，未核实线上 APK 或 OTA 是否已更新。

## 尚未对齐的功能

| 功能 | RN 当前实现 | iOS 当前状态 | 接入条件 |
| --- | --- | --- | --- |
| 按学号提示疑似研究生 | 十位学号的第 5、6 位匹配 `30`、`39`、`59` 时提示本科生与研究生教务系统分离，关闭后仍可尝试登录 | 只有固定说明，未做学号判断或弹窗 | 先核实学号规则与实际需求；不能据此认定用户身份或阻止登录 |
| 调课信息总览 | `RescheduleNotificationScreen` 调用 `jwxt.getReschedulingNews`，向学校 `/xtgl/index_cxDbsy.html?doType=query` POST 查询已读、未读通知 | 工具箱没有总览入口；单门课程调课详情已通过 `/jw/schedule/personal/reschedules` 接入，不能当作总览替代 | 后端提供总览查询契约并验证响应；不能把按教学班查询接口当作全量通知接口 |
| 选课课程列表 | `courseApi.courseSelection.getList` 向学校 `/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html` POST 查询，带课程类别、分页、关键词及写死的 `xkkz_id` | 无对应入口；已选课程和校选课查漏是不同功能 | 后端提供可用的选课批次及列表查询契约，不复制 RN 写死的选课批次 |
| 完整期末评教 | 总览页面仍调用教务直连；API 文件定义了 `/jw/evaluation` 代理方法，但当前没有页面调用；详情、保存、提交使用学校 `/xspjgl/` 接口 | 工具箱保留不可用入口；已有总览和本地模板代码，没有详情填写、保存、提交或批量评教闭环 | 先恢复总览代理，再提供详情、保存和提交契约；仅总览可用也不能宣称完整评教可用 |

入口以 [ToolboxCatalog](../../App/Shell/ToolboxCatalog.swift) 为准，评教已有实现见 [EvaluationViews](../../Packages/FeatureCourse/Sources/FeatureCourse/Evaluation/EvaluationViews.swift)。遵循现有迁移决定，暂不另行实现教务直连绕过代理。

## 2026-11-15 后端实测

以下保留当日既有的未登录 GET 探测结果，本次更新源码基准时未重新请求这些接口。探测目标为 `https://api.tool.gxutech.xyz`，只记录状态和通用错误信息，不提交评教或修改学校数据。

| 路径 | HTTP | 结果及解释 |
| --- | --- | --- |
| `/jw/evaluation` | 404 | `Cannot GET /jw/evaluation`；这是 RN API 文件定义、iOS 总览代码使用的代理路径 |
| `/jw/schedule/adjust`、`/jw/timeShift`、`/jw/rescheduling` | 404 | 均返回对应的 `Cannot GET`；这些是历史候选路径，不是已确认的代理契约 |
| `/jw/courseSelection`、`/jw/course-selection` | 404 | 均返回对应的 `Cannot GET`；这些是历史候选路径，不是已确认的代理契约 |
| `/docs-json` | 200 | 公开 OpenAPI 目录含 65 条路径；未发现评教、调课总览或选课课程列表代理，单课调课路径为 `/jw/schedule/personal/reschedules` |
| `/openapi.json`、`/api-json`、`/swagger-json` | 404 | 这些常见地址不提供目录；实际目录为 `/docs-json` |
| `/jw/profile/startDay` | 200 | 响应 `code: 200`、`message: success`，作为同一后端可达性的对照 |

该次探测没有本地 `.secrets/account.env`，未做登录后的业务请求。404 只能证明上述方法和路径本次不可用，不能证明不存在其他未公开路径，也不能排除认证相关的路由差异。此前基准及本次 RN 提交直接修改的文件均未提供调课总览和选课列表的新代理契约；适配器依赖升级也不能直接证明后端已有可用接口。后续拿到正式契约或部署信息后，应重新进行认证读取验证。

## 已有的 iOS 实现

以下项目已有 iOS 实现，不再列为功能缺失。部分能力为原生版新增，不表示 RN 提供相同功能；源码和自动化验证不替代真实账号联调。

| 项目 | 当前 iOS 实现 |
| --- | --- |
| 空闲教室 | 时间查询、教室查询、楼栋楼层选择、周缓存和冷却控制，位于 `FeatureCampus/EmptyClassroom` |
| 考勤 v2 | `/attendance/v2/captcha`、`/attendance/v2/login` 已接入，位于 `GxuAuth/AttendanceSession.swift` |
| 校选课查漏 | 请求 `/jw/elective-progress`，校验账号并隔离缓存，位于 `FeatureCourse/ElectiveStrategy` |
| 本科生提示 | 教务账号页已显示本科生使用范围与研究生课表提示 |
| 单门课程调课详情与本地调课 | 展示教务调课前后安排并突出调整后信息；本地调整按账号、学期保存并同步首页和小组件，不提交教务 |
| 全部反馈和我的反馈 | `/feedback/public`、`/feedback/mine/{学号}`，支持分页、个人列表登录提示及切账号清空 |
| 考试详情与系统日历 | 类别、状态、待定考场或座位提示、复制信息；有效考试可经系统编辑页确认添加到日历，后续变动不自动同步 |
| 历史成绩 | 全部学期分组、课程或教师搜索、完整分页与账号缓存隔离；保留重修前后原始记录 |
| 反馈草稿 | 按账号保留本地草稿、提交状态及失败内容，成功后清除本次草稿并可进入“我的反馈” |
| 课表导出 | “导出课表”从本地缓存生成周课表图片；“教务原版课表”传递当前账号 Cookie，主页面与新窗口共用临时会话，提供登录失效及加载错误提示 |

## 保留的差异与待验证事项

- RN 暂时隐藏了分享课表，iOS 保留本周课表分享及本地图片导出，不属于 iOS 缺失功能。考试添加到日历与课表图片导出是不同功能，尚未实现整张课表写入系统日历。
- iOS 使用原生界面、GRDB 和 WidgetKit，不移植 RN 组件、数据库迁移、Android 小部件及 OTA 流水线。
- 校选课小学期映射曾出现 `/jw/elective-progress` 的 `term=3` 与 `/jw/score` 的 `term=0` 不一致。iOS 保留 `ElectiveReviewResolver` 按课程名、学分、学年和对应学期唯一匹配的核对逻辑。本次没有真实账号响应，尚未确认后端是否已修复。
- 真实账号、校园网、iOS 18、辅助功能与小组件共享等未覆盖范围见[迁移索引](README.md)及[设备检查清单](device-checklist.md)。
