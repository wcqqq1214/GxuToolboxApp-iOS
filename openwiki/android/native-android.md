---
type: platform
title: 原生 Android
description: "Android 原生层：Manifest 权限与服务、OTA bundle 选择，以及基于 FileProvider 的文件打开桥接。"
tags: [android, native, manifest, ota, fileprovider, widget]
---

# 原生 Android

应用仅支持 Android。大部分业务在 React Native JS 中，原生侧只负责启动、OTA bundle 选择、`FileProvider` 文件打开桥、桌面课表小组件和刷新服务（见[小组件总览](../widget/overview.md)）。

## Manifest

文件：`android/app/src/main/AndroidManifest.xml`，包名 `com.gxu_tool_app`。

### 权限

| 权限 | 用途 |
|---|---|
| `INTERNET`、`ACCESS_NETWORK_STATE` | 所有 HTTP 客户端 |
| `WRITE_EXTERNAL_STORAGE`（maxSdk 28）、`READ_EXTERNAL_STORAGE`（maxSdk 32）、`READ_MEDIA_IMAGES`（33+） | 头像、导出截图等媒体读取 |
| `REQUEST_INSTALL_PACKAGES` | OTA 在应用内安装 APK |
| `MANAGE_EXTERNAL_STORAGE` | 导出功能所需的全文件访问 |
| `ACCESS_FINE_LOCATION` | 地图/导航工具 |
| `VIBRATE` | UI 反馈 |
| `FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE` | `TimeTickService` 刷新小组件 |
| `POST_NOTIFICATIONS` | Android 13+ 通知 |

### 组件

- `MainActivity` 为 `singleTask`，注册启动器、`DOWNLOAD_COMPLETE` 以及 `http`/`https` 的 `VIEW` deep link。没有 host 限制，外部任意 http(s) 链接都可能解析到该 Activity。
- `<application android:usesCleartextTraffic="true">` 允许全局明文 HTTP（当前后端代理和 OTA 地址需要）。
- `MainApplication` 通过 `android:name=".MainApplication"` 注册。
- `FileProvider` authority 为 `${applicationId}.provider`（正式包为 `com.gxu_tool_app.provider`），路径见 `res/xml/provider_paths.xml`。
- `RNWidgetCollectionService` 来自 `react-native-android-widget`，需要 `BIND_REMOTEVIEWS`。
- `TimeTickService` 使用 `foregroundServiceType="specialUse"`，按分钟刷新小组件，通知 channel 为 `TimeTickServiceChannel`。
- `CourseScheduleWidgetProvider` 处理 `APPWIDGET_UPDATE` 和自定义 `WIDGET_CLICK`。
- `<queries>` 声明高德、百度包名及 `androidamap`/`baidumap` scheme。

## MainActivity

`MainActivity.kt` 有两个特殊行为：

1. 在 `super.onCreate` 前移除 `android:support:fragments` 和 `androidx.lifecycle.BundlableSavedStateRegistry.key`，这是 `react-native-screens` 的 fragment 恢复规避方案。
2. `getMainComponentName()` 返回 `gxu_tool_app`；`createReactActivityDelegate()` 返回启用 Fabric 的 `DefaultReactActivityDelegate`。

## OTA bundle 选择

`MainApplication.kt` 的 `getOTABundlePath()` 读取 `filesDir/ota_version`，格式必须是 `otaVersionCode|appVersionCode`：

1. 格式不是两段时删除标记并返回 `null`。
2. `savedAppVersion` 必须等于 `BuildConfig.VERSION_CODE`；否则删除标记并回退内置 bundle。
3. 校验通过后读取 `filesDir/ota/{otaCode}/index.android.bundle`，文件不存在也回退内置 bundle。

## OpenWithModule

`OpenWithModule.kt` 暴露 `NativeModules.OpenWithModule.openFile(filePath)`：用 `FileProvider.getUriForFile` 生成 `content://` URI，创建带 `*/*` 和 `FLAG_GRANT_READ_URI_PERMISSION` 的 `ACTION_VIEW`，再通过 chooser 启动。`MainApplication.kt` 以 `add(OpenWithPackage())` 注册，课表导出页面用它把 HTML 交给外部应用打开。

## 构建元数据

- `package.json`：`versionCode` 20103，版本 `2.1.3 beta`，OTA 地址 `https://file.unde.site/GxuToolApp/version.json`。
- `build-ota` 会生成 Metro bundle，`scripts/gen-ota-info.ts` 输出 `dist/version.json` 和 `dist/ota-info.json`。
- `android/app/build.gradle` 的 `namespace`/`applicationId` 为 `com.gxu_tool_app`，debug 增加 `.debug` 后缀；release 启用 R8/ProGuard，并将 APK 重命名为 `gxu_tool_app-v${versionName}.apk`。
- debug/release keystore 已提交仓库且密码明文写在 `build.gradle`，这是凭据轮换风险；生产发布前必须更换。

## 验证

- `pnpm android`（或 `yarn android`）验证原生编译运行。
- 构建 OTA 后检查 `filesDir/ota/` 和 `ota_version`。
- 从课表导出页面调用 `openFile`，确认出现 Android 应用选择器。
