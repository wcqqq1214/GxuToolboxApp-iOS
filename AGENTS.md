# AGENTS.md

## 仓库与构建

- 本仓库是西大工具箱的原生 iOS fork。应用与 Widget 工程都在 `ios-native/`，最低系统版本为 iOS 18。
- 默认在用户原仓库创建任务分支。只有用户明确要求时才创建 Git worktree。
- `ios-native/project.yml` 是 XcodeGen 的工程源文件。工程设置改在这里，生成的 `.xcodeproj`、构建产物和本地签名配置留在本机。
- 从仓库根目录运行 `bash ios-native/scripts/build.sh` 构建 App 和 Widget。用 `bash ios-native/scripts/test.sh <PackageName>` 跑相关测试。可通过 `SIM_ID` 指定已有模拟器。
- 测试和演示使用脱敏 fixture 或虚构数据。账号、令牌、签名配置和原始响应不得提交。

## 代码入口与边界

- `ios-native/App/GxuToolApp.swift` 是应用入口，`App/Composition/` 负责依赖装配，`App/Shell/` 负责导航和跨功能接线。
- 功能代码按职责放在 `ios-native/Packages/` 对应的 Swift Package。跨功能网络、认证和存储使用 `GxuCore` 提供的边界，通用 SwiftUI 组件放在 `GxuDesign`。
- 外部响应先解码为内部模型，再交给页面。缓存需要按账号和学期隔离时，在存储层明确作用域。刷新失败时保留可用缓存。
- `ios-native/Widget/` 是 WidgetKit 扩展，课表快照、共享模型及小组件视图位于 `FeatureCourse` 的 `ClassWidgetKit`。同时改 App 和 Widget 时检查 App Group 数据兼容性。
- Swift 6 开启严格并发检查。iOS 26 专用 API 需要可用性判断和 iOS 18 降级路径。

## 上游与文档

- GitHub fork 关系保留。RN 行为以 GitLab `v2.2` 为对照，按功能移植所需改动。iOS 的实际行为以当前 Swift 源码和测试为准。
- [README](README.md) 是当前构建入口。[迁移记录](docs/ios-migration/) 与 [接口参考](docs/api-docs/) 含历史 RN 路径和当时的联调结论。
- 真机签名和联调见 [设备检查清单](docs/ios-migration/device-checklist.md)。
