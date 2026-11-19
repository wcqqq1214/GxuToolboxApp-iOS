# RN v2.2 与 iOS 对齐状态

2026-11-15 核对时，RN 基准为 `origin/v2.2` 的 `233c3ca1`，iOS 基准为 `638fece0`；2026-11-17 对照 RN `bea9b6c1` 后，iOS 同步补上了转专业前的学年选择和物理实验课表更新。文中日期按北京时间（UTC+8）记录，后端探测数据保留各自核对时的日期。

## RN 上游动态

2026-11-15 拉取 GitLab 上游后，`origin/v2.2` 从 `774f47a8` 推进到 `233c3ca1`，多了下面两笔提交（作者时间均为 11 月 14 日，15 日 21:09:57 合入，提交时间不代表 OTA 发布时间）：

| 提交 | 源码变化 | 对原生 iOS 的影响 |
| --- | --- | --- |
| [`ab9d701d`](https://gitlab.unde.site/gxutool/gxu_tool_app/-/commit/ab9d701dcf1351da69964ea50203dc4ab181cdf4) | 教务学号改为十位分格输入，按 2/4/4 分组；十位学号第 5、6 位为 `30`、`39`、`59` 时，在当前页面生命周期内弹一次疑似研究生提示；顺带抽出了登录说明卡片 | iOS 已经固定展示本科生适用范围和研究生课表说明，暂未加学号弹窗；不需要照搬 RN 的分格输入组件 |
| [`233c3ca1`](https://gitlab.unde.site/gxutool/gxu_tool_app/-/commit/233c3ca106d7d48c417fb1a1c200a3e7414315c8) | OTA 在有底包提交时检查累计差异，旧底包缺少记录时回退到 MR/push 比较基线；只剥掉 Android `versionName` 的 beta 后缀即放行；适配器开发依赖从 1.1.1 升至 1.2.1 并清理重复运行时依赖 | 属于 RN 与 Android 发布链，不移植到 Swift 构建流程；本轮暂未检查适配器发布包内容 |

截至当时，GitLab `origin/main` 仍停在 11 月 11 日的 `c6693990`，上述改动尚未合入主干；GitHub 原项目 `upstream/v2.2` 停在 10 月 28 日的 `0f54a4c1`。RN 源码版本依然是 `2.2.0`（构建号 `20200`），暂未核实线上 APK 或 OTA 是否同步。

## 尚未对齐的功能

| 功能 | RN 当前实现 | iOS 当前状态 | 补齐条件 |
| --- | --- | --- | --- |
| 按学号提示疑似研究生 | 十位学号第 5、6 位命中 `30`、`39`、`59` 时提示本科生与研究生教务系统分离，关闭后仍可继续尝试登录 | 只展示固定说明文字，没有按学号弹窗 | 核实学号编码规则与真实需求；即便加上提示也不能据此拦截登录 |
| 调课信息总览 | `RescheduleNotificationScreen` 调用 `jwxt.getReschedulingNews`，向学校 `/xtgl/index_cxDbsy.html?doType=query` POST 查询已读和未读通知 | 工具箱暂无总览入口；单门课程详情已接入 `/jw/schedule/personal/reschedules`，但这不是全量通知接口 | 等待后端提供总览查询契约并验证响应结构 |
| 选课课程列表 | `courseApi.courseSelection.getList` 向学校 `/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html` POST 查询，携带课程类别、分页、关键词和写死的 `xkkz_id` | 暂无入口（已选课程和校选课查漏属于其他功能） | 等待后端提供选课批次与列表查询契约，不复制 RN 里写死的选课批次 ID |
| 完整期末评教 | 总览页面仍在直连教务；API 文件定义了 `/jw/evaluation` 代理方法但没有页面调用；详情、保存、提交走学校 `/xspjgl/` 接口 | 工具箱保留「即将上线」不可用入口；代码里已有总览和本地模板界面，缺少详情填写、保存、提交和批量评教流程 | 先等总览代理恢复，再补齐详情、保存和提交契约；光有总览接口还不算可用 |

工具箱入口清单以 [ToolboxCatalog](../../App/Shell/ToolboxCatalog.swift) 为准，评教已有界面见 [EvaluationViews](../../Packages/FeatureCourse/Sources/FeatureCourse/Evaluation/EvaluationViews.swift)。按目前的迁移策略，暂不绕过代理去直连教务评教或选课接口。

## 2026-11-15 后端实测

下面是 2026-11-15 对 `https://api.tool.gxutech.xyz` 所做的未登录 GET 探测结果（之后核对 RN 源码时没有重跑这批请求）。探测只记录 HTTP 状态和常规错误信息，不会提交评教或改动学校数据。

| 路径 | HTTP | 返回结果与说明 |
| --- | --- | --- |
| `/jw/evaluation` | 404 | `Cannot GET /jw/evaluation`；这是 RN API 文件与 iOS 评教总览代码预期的代理路径 |
| `/jw/schedule/adjust`、`/jw/timeShift`、`/jw/rescheduling` | 404 | 均返回对应的 `Cannot GET`；属于历史猜测路径，不是已确认的代理接口 |
| `/jw/courseSelection`、`/jw/course-selection` | 404 | 均返回对应的 `Cannot GET`；同样不是已确认的代理接口 |
| `/docs-json` | 200 | 公开 OpenAPI 目录包含 65 条路径，里面没有评教、调课总览和选课列表；单课调课路径为 `/jw/schedule/personal/reschedules` |
| `/openapi.json`、`/api-json`、`/swagger-json` | 404 | 常见 Swagger 地址均无目录，实际入口是 `/docs-json` |
| `/jw/profile/startDay` | 200 | 返回 `code: 200`、`message: success`，用于对照确认同一后端可达 |

那次探测时手头没有 `.secrets/account.env`，没法测需要登录态的接口。返回 404 只说明这些路径当时在未登录 GET 下不可用，不能完全排除认证态路由差异或未公开接口的可能；不过核对 RN 近期提交改过的文件时，也确实没看到调课总览和选课列表的新代理契约，适配器依赖升级也不代表后端已有对应路由。等拿到正式接口文档或部署确认后，再用真实账号复测。

## 已有的 iOS 实现

下面这些功能在 iOS 端已经落地，不再算作缺失。部分是原生版新增能力，不代表 RN 版也有对应实现；实际效果仍以真实账号联调为准。

| 项目 | 当前 iOS 实现 |
| --- | --- |
| 空闲教室 | 支持按时段、教室、楼栋和楼层筛选，带周缓存与冷却控制（位于 `FeatureCampus/EmptyClassroom`） |
| 考勤 v2 | 已接入 `/attendance/v2/captcha` 与 `/attendance/v2/login`（位于 `GxuAuth/AttendanceSession.swift`） |
| 校选课查漏 | 请求 `/jw/elective-progress` 并校验账号、隔离缓存（位于 `FeatureCourse/ElectiveStrategy`） |
| 本科生说明 | 教务账号页已提示本科生适用范围及研究生课表说明 |
| 调课详情与本地调课 | 对照展示教务调课前后安排并高亮新信息；本地调课按账号和学期保存并同步到首页及小组件，不写回教务 |
| 全部反馈与我的反馈 | 接入 `/feedback/public` 与 `/feedback/mine/{学号}`，支持分页、未登录提示和切号清空；仅在 `adminNote` 非空时标为「已回复」 |
| 考试详情与日历写入 | 展示考试类别、实时状态、待定提示与信息复制；起止时间有效的场次可通过系统编辑页确认加进日历，后续变动需手动同步 |
| 历史成绩 | 支持全学期分组、按课程或教师搜索、完整分页刷新与账号隔离，保留重修前后原始记录 |
| 转专业前的学年 | 学号指向更早入学年份时自动补齐共用学年选择器（末年仍受教务学制和当前学年约束），实际可查范围以教务返回为准 |
| 物理实验与课表同步 | 首页与个人课表刷新当前学期时，通过统一认证直连实验中心并更新缓存（失败保留旧安排）；课表按日期展示实验项目名，并同步更新首页和小组件 |
| 反馈草稿 | 按账号保存在本地并记录提交状态，提交失败保留输入，成功后清掉草稿并支持直达「我的反馈」 |
| 课表导出 | 「导出课表」直接用本地缓存生成周课表图片；「教务原版课表」传递当前账号 Cookie，主页面与新窗口共用临时会话，并分开提示登录失效和加载错误 |

## 保留的差异与待验证事项

- RN 目前暂时隐藏了分享课表，iOS 保留本周课表分享和本地图片导出，这不算缺失功能。考试单场加日历与课表图片导出相互独立，目前还没做整张课表批量写入系统日历。
- iOS 基于原生控件、GRDB 和 WidgetKit 实现，不搬运 RN 组件、RN 数据库迁移脚本、Android 小组件以及 OTA 热更新流水线。
- 校选课小学期映射曾遇到 `/jw/elective-progress` 的 `term=3` 与 `/jw/score` 的 `term=0` 不一致的问题。iOS 通过 `ElectiveReviewResolver` 按课程名、学分、学年和对应学期做唯一匹配；目前还没用真实账号跑过，不确定后端是否已经修掉这个差异。
- 真机、真实账号、校园网、iOS 18、辅助功能和小组件共享等尚未覆盖的范围，见[迁移索引](README.md)和[设备检查清单](device-checklist.md)。
