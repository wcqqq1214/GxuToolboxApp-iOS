<h1 align="center">西大工具箱 · iOS</h1>

广西大学校园工具箱的原生 iPhone 版，使用 SwiftUI 和 WidgetKit，支持 iOS 18 及以上版本。

## 功能

- 查看个人和班级课表，添加自定义课程，导出课表。
- 查询考场、成绩、考勤记录和校选课完成情况，计算绩点。
- 查找教师、空闲教室和教学楼，查看校园网用量、学校文件和调休安排。
- 通过课表小组件和实时活动查看当前与下一节课。

## 本地运行

需要 macOS、提供 Swift 6 和 iOS 26 SDK 的 Xcode、已安装的 iOS 模拟器运行时，以及 XcodeGen。首次构建需要联网解析 Swift Package 依赖。

```sh
git clone https://github.com/wcqqq1214/GxuToolboxApp-iOS.git
cd GxuToolboxApp-iOS
bash scripts/build.sh
```

脚本根据 [project.yml](project.yml) 生成 Xcode 工程，构建 App 和 Widget。打开生成的 `GxuToolApp.xcodeproj`，选择模拟器和 `GxuToolApp` scheme 即可运行。Debug 启动参数加上 `-GxuDemo` 后，可用演示数据查看首页和课表。

运行包测试可用 `bash scripts/test.sh FeatureSchedule FeatureCourse`。构建和测试脚本都支持用 `SIM_ID` 指定已有的模拟器。真机签名和安装见[设备检查清单](docs/ios-migration/device-checklist.md)。

## 数据与文档

查询个人课表、成绩和考勤等信息需要登录相应账号。部分校内系统需要校园网或 VPN。演示和测试使用虚构数据或脱敏样本。

- [接口参考](docs/api-docs/)与[契约记录](docs/contracts/)
- [脱敏样本与接口参数](Fixtures/sanitized/README.md)
- [原生 iOS 迁移记录](docs/ios-migration/)（旧文档中的 `ios-native/` 对应现在的仓库根目录）

## 项目来源

本项目源自 [GxuTool/GxuToolboxApp](https://github.com/GxuTool/GxuToolboxApp)，在此维护原生 iOS 版。功能和接口以 [React Native v2.2](https://gitlab.unde.site/gxutool/gxu_tool_app/-/tree/v2.2) 为移植对照，最初的对齐基线为 [`9b98f953`](https://gitlab.unde.site/gxutool/gxu_tool_app/-/tree/9b98f953)。
