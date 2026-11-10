# 西大工具箱 · iOS

广西大学校园工具箱的原生 iOS 版。应用使用 SwiftUI，支持 iOS 18 及以上版本，提供个人和班级课表、考试、成绩与 GPA、考勤、空闲教室、学校文件，以及课表小组件和实时活动。

本仓库保留 GitHub fork 关系和提交历史。默认分支维护原生 iOS 工程，Android 版由上游项目维护。[GitHub 上游](https://github.com/GxuTool/GxuToolboxApp) · [GitLab RN v2.2](https://gitlab.unde.site/gxutool/gxu_tool_app/-/tree/v2.2)

## 模拟器构建

需要 macOS、支持 Swift 6 和 iOS 26 SDK 的 Xcode、已安装的 iOS Simulator runtime，以及 XcodeGen。首次构建需要联网解析 Swift Package 依赖。

在仓库根目录运行：

```sh
bash ios-native/scripts/build.sh
bash ios-native/scripts/test.sh FeatureSchedule FeatureCourse
```

构建脚本通过 [project.yml](ios-native/project.yml) 生成 Xcode 工程并构建 `GxuToolApp` 和 `GxuWidget`。脚本会为当前分支选择或创建模拟器，也可用 `SIM_ID` 指定已有模拟器。

要在 Xcode 中运行，进入 `ios-native/` 执行 `xcodegen generate`，打开生成的 `GxuToolApp.xcodeproj`，选择模拟器和 `GxuToolApp` scheme。Debug scheme 可在运行参数中加 `-GxuDemo`，用演示数据查看课表和首页。登录后的线上功能需要对应账号，部分校内系统需要校园网或 VPN。

## 项目结构

| 路径 | 内容 |
| --- | --- |
| [ios-native/App/](ios-native/App/) | 应用入口、依赖装配、首页和工具箱 |
| [ios-native/Packages/](ios-native/Packages/) | Swift Packages，包含认证、网络、存储、设计组件和功能模块 |
| [ios-native/Widget/](ios-native/Widget/) | WidgetKit 扩展和实时活动 |
| [ios-native/UITests/](ios-native/UITests/) | 模拟器 UI 测试 |
| [ios-native/scripts/](ios-native/scripts/) | 构建、测试和打包脚本 |
| [docs/api-docs/](docs/api-docs/) 与 [docs/contracts/](docs/contracts/) | 接口参考和契约记录 |
| [docs/ios-migration/](docs/ios-migration/) | 迁移历史、RN 对照和真机检查清单 |

## 对照上游

RN 行为和接口对照以 GitLab `v2.2` 为准。本轮清理前的对齐基线为 `9b98f953`。查看上游改动后，把需要的行为移植到 Swift。迁移文档中的 `src/`、`android/` 等路径指向当时的 RN 源码。[RN 对齐基线](https://gitlab.unde.site/gxutool/gxu_tool_app/-/tree/9b98f953)
