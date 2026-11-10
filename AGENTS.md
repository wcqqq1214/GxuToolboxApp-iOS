# AGENTS.md

## 开发流程

- 默认采用仓库内的 [`poteto-mode`](.agents/skills/poteto-mode/SKILL.md)。常规任务由一个 agent 完成，按用户要求用 [`pstack-interrogate`](.agents/skills/pstack-interrogate/SKILL.md) 做独立审查。本文件优先于 skill 的委派和发布默认值。
- 编写或审查 SwiftUI 时，使用 [`swiftui-pro`](.agents/skills/swiftui-pro/SKILL.md)，并遵循本项目的 Swift 与 iOS 版本要求。[Skill 来源](.agents/README.md)
- 在用户打开或指定的原仓库工作，保留已有修改和暂存内容。开始任务时运行 `git fetch github main`，核对当前分支及本地 `main` 与远端的差异。拉取失败时说明情况，有未推送提交或分歧时先确认归属。
- 新任务默认从最新 `github/main` 创建本地分支，Git worktree 仅在用户明确要求时创建。`github` 用于 iOS 开发和发布，`origin` 是 RN 的 GitLab 上游。
- 验证后按用户授权提交、合并和推送，默认不创建 PR。核对暂存 diff，只提交本任务改动，使用简短英文提交信息。发布前再次 fetch，优先 `git merge --ff-only`，推送用 `git push github main`。确认远端包含任务提交后，按授权删除已合入分支。

## 代码入口与边界

- `App/GxuToolApp.swift` 是入口，`App/Composition/` 负责装配，`App/Shell/` 负责导航和跨功能接线。
- 功能放在 `Packages/` 对应的 Swift Package。网络、认证和存储共用 `GxuCore`，界面优先使用原生控件和 [GxuDesign](Packages/GxuDesign/README.md)。
- 在现有 target 内按功能收拢专属的页面、状态、模型、请求和缓存。单一功能的测试放在对应测试 target 下的同名目录。共享服务和跨功能测试留在共同的 target 中。
- 从 [ToolboxCatalog](App/Shell/ToolboxCatalog.swift) 按工具箱名称定位页面，从 [RootView](App/Shell/RootView.swift) 追踪标签页和跨功能接线。
- 空闲教室的楼层分组在 [EmptyClassroomFloor](Packages/FeatureCampus/Sources/FeatureCampus/EmptyClassroom/EmptyClassroomFloor.swift)，测试在 [EmptyClassroom](Packages/FeatureCampus/Tests/FeatureCampusTests/EmptyClassroom/)，运行 `bash scripts/test.sh FeatureCampus`。
- 教师查询的请求在 [TeacherAPI](Packages/FeatureMisc/Sources/FeatureMisc/Teachers/TeacherModels.swift)，测试在 [Teachers](Packages/FeatureMisc/Tests/FeatureMiscTests/Teachers/)，运行 `bash scripts/test.sh FeatureMisc`。课表接线在 [TeacherLookup](App/Shell/TeacherLookup.swift)，改动它时覆盖 App 单元测试。
- 外部响应解码为内部模型后交给页面。缓存按需隔离账号和学期，刷新失败保留可用缓存。
- `Widget/` 是 WidgetKit 扩展，共享模型、课表快照和视图位于 `Packages/FeatureCourse/Sources/ClassWidgetKit/`。修改共享数据时检查 App Group 兼容性。
- 小组件的下一节课由 [SnapshotProvider](Packages/FeatureCourse/Sources/ClassWidgetKit/SnapshotProvider.swift) 调用 [NextCourseCalculator](Packages/FeatureSchedule/Sources/ScheduleKit/Today/NextCourses.swift) 计算。[ScheduleTimelineTests](Packages/FeatureCourse/Tests/ClassWidgetKitTests/ScheduleTimelineTests.swift) 验证显示时序，相关测试运行 `bash scripts/test.sh FeatureSchedule FeatureCourse`。
- 使用 Swift 6 严格并发检查，最低支持 iOS 18。iOS 26 API 必须有可用性判断和降级路径。

## 构建与验证

- 工程设置修改 `project.yml`。XcodeGen 生成的工程、Info.plist 和 entitlements，以及构建产物和签名配置留在本机。
- 从根目录运行 `bash scripts/build.sh` 构建 App 和 Widget，运行 `bash scripts/test.sh <PackageName>` 测试相关包。不带包名时运行全部包测试、App 单元测试和脚本回归。App 接线改动须覆盖 `AppTests`。可用 `SIM_ID` 指定模拟器。
- 缺陷先复现再验证，测试覆盖可观察的行为。UI 改动按影响范围走查流程、浅深色、无障碍及系统降级，保留必要的操作反馈和错误提示。自动化入口为 `scripts/run-e2e-ui.sh`，执行前检查所需配置。真机联调见[设备检查清单](docs/ios-migration/device-checklist.md)。
- 文档改动检查事实、链接和 diff。交付时报告实际验证结果和未覆盖范围。
- 测试和演示使用脱敏或虚构数据。账号、令牌和原始响应不得提交。

## 上游与文档

- 项目来源见 [README](README.md)。移植时对照 RN `v2.2`，当前行为以 Swift 源码和测试为准。[迁移记录](docs/ios-migration/)和[接口参考](docs/api-docs/)用于历史对照。
- 行为或契约变化时更新对应文档，删除过时规则。复用教训优先落实为测试或结构约束。任务日志、临时截图和一次性报告留在仓库外。
