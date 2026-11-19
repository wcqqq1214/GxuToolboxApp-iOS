<p align="center">
  <img src="docs/assets/readme-icon.png" width="96" height="96" alt="西大工具箱图标">
</p>

<h1 align="center">西大工具箱 · iOS</h1>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-18%2B-1D4ED8?style=flat-square&amp;logo=apple&amp;logoColor=white" alt="iOS 18 及以上">
  <img src="https://img.shields.io/badge/Version-2.2.0-2F6FED?style=flat-square" alt="版本 2.2.0">
  <img src="https://img.shields.io/badge/Swift-6-DB3D2A?style=flat-square&amp;logo=swift&amp;logoColor=white" alt="Swift 6">
</p>

广西大学校园工具箱的原生 iPhone 客户端，基于 SwiftUI 和 WidgetKit 开发，支持 iOS 18 及以上系统。平时查课表、看考场、算绩点、查考勤或翻学校文件，不用在教务、统一认证和 OA 之间来回切网页，在一个 App 里就能完成。

## 功能

- **课表与今日日程**：「今天」页展示正在上或接下来的课、当天剩余安排、近期考试和假期倒计时；周/日课表支持个人与班级课表、自定义课程、本地调课和教务调课对比，同时标出物理实验和考勤状态。需要留底或分享时，可以导出周课表图片，也能直接打开教务原版课表网页保存页面。
- **小组件与系统集成**：提供主屏幕和锁屏课表小组件、灵动岛与锁屏实时活动，并支持通过快捷指令或 Siri 查询「今天的课」「明天的课」和「下一场考试」。
- **考场、成绩与学业**：查看考场并把单场考试一键加进系统日历；按学期查看历史成绩、搜索课程或教师、核对平时分并按西大规则计算绩点，也支持查看考勤记录和校选课学分进度。
- **校园常用工具**：找空闲教室、查教师资料与课表、看校园网用量、读学校 OA 文件、查看调休与节假日安排、同步物理实验和金工实训课表，还带校内地点导航、全校实时课表和教学楼平面图。
- **账号与个性化**：分别管理教务、统一认证、考勤和 OA 账号并保存在本机钥匙串；支持浅深色模式、主题色、自定义背景图和意见反馈（可存本地草稿），使用统计默认关闭。

## 本地运行

本地构建需要 macOS、带 Swift 6 和 iOS 26 SDK 的 Xcode（装好对应的 iOS 模拟器运行时），以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。首次编译会联网拉取 Swift Package 依赖。

```sh
git clone https://github.com/wcqqq1214/GxuToolboxApp-iOS.git
cd GxuToolboxApp-iOS
bash scripts/build.sh
```

脚本会生成 `GxuToolApp.xcodeproj` 并构建 App 与小组件。之后用 Xcode 打开工程，选择模拟器和 `GxuToolApp` scheme 即可运行。如果手头没有校内账号，可以在 scheme 的启动参数里加上 `-GxuDemo`，直接用内置的示例数据体验界面。

运行单元测试可以使用 `bash scripts/test.sh`，也可以在后面接包名做定向测试（例如 `bash scripts/test.sh FeatureSchedule FeatureCourse`）。构建和测试脚本都支持用 `SIM_ID` 指定已有的模拟器；真机安装、签名和 TestFlight 打包步骤见[真机验证清单](docs/ios-migration/device-checklist.md)。

## 目录结构

- `App/`：应用入口、依赖装配、底部标签页和首页壳层
- `Packages/`：按模块拆分的 Swift Packages，包含核心基础设施 `GxuCore`、设计系统 `GxuDesign` 与各业务包
- `Widget/`：WidgetKit 桌面与锁屏小组件、灵动岛实时活动扩展
- `Fixtures/`：本地开发与单元测试使用的脱敏接口样本
- `scripts/`：构建、测试、真机安装、打包和代码检查脚本

## 账号、网络与文档

查询个人课表、成绩、考勤和 OA 文件需要登录对应的西大账号。在校外访问统一认证、物理实验、金工实训或 OA 时，如果遇到连接受限，切换到校园网或校园 VPN 即可。

- [接口参考](docs/api-docs/)：整理自上游 React Native 项目的学校系统与代理接口说明
- [脱敏样本说明](Fixtures/sanitized/README.md)：测试用 JSON 样本的字段说明、脱敏方式和抓取方法
- [iOS 迁移记录](docs/ios-migration/README.md)：原生版本保留的设计决策、缓存容灾和待验证事项
- [RN 上游对照与差异](docs/ios-migration/rn-v2.2-gap.md)：与 React Native v2.2 的对齐状态和后端接口实测结果

## 项目来源

原生 iOS 版源自 [GxuTool/GxuToolboxApp](https://github.com/GxuTool/GxuToolboxApp)，功能和接口主要参考 [React Native v2.2](https://gitlab.unde.site/gxutool/gxu_tool_app/-/tree/v2.2)。
