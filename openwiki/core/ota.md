---
type: infrastructure
title: OTA 更新
description: JS bundle OTA 的版本生成、发现、下载、原生校验、清理和 APK 更新 UI。
tags: [core, ota, updates, infrastructure]
---

# OTA 更新

应用同时支持 OTA JS bundle 和完整 APK 更新，地址均来自 `package.json` 的 `PackageJSON.versionJsonUrl`：`https://file.unde.site/GxuToolApp`。OTA 是当前维护路径，APK 是完整版本更新页。

## 构建版本（`pnpm build-ota`）

`scripts/gen-ota-info.ts` 在 Metro bundle 生成后读取 `package.json`：

- `versionName = "${pkg.version}-${MMDD}${seq}"`，`seq` 默认 1，也可取远端当天最大序号 + 1，命令行 `pnpm build-ota -- 12` 可指定。
- `versionCode = ${pkg.versionCode}${MMDD}${seq}`，必须大于 APK 的 versionCode。
- bundle 名为 `{pkg.versionCode}{MMDD}{seq}.index.android.bundle`，放到 `dist/{pkg.versionCode}/`，并生成 `dist/version.json`、`dist/ota-info.json` 和历史文件。
- 版本字符串含 `beta` 使用 beta channel，否则使用 release；`src/core/ota.ts` 和 `UpdateCard` 使用同一规则。

## 发现与下载

`src/core/ota.ts`：

- `checkOTA()` 请求 `${versionJsonUrl}?_=${Date.now()}`，按 channel 和当前 `PackageJSON.versionCode` 找到 APK 条目，再取 `ota[]` 中最大的 versionCode；只有它大于 MMKV 的 `ota_version_code` 才下载。
- `downloadAndApplyOTA(ota)` 用 `react-native-blob-util` 写入 `DocumentDir/ota/{versionCode}/index.android.bundle`，再写入 `DocumentDir/ota_version`（`otaVersionCode|appVersionCode`），更新 MMKV 两个版本 key，并删除其他 OTA 目录。新 bundle 在下次启动生效。
- `cleanStaleOTA()` 在启动时检查 OTA 所属 APK 版本；APK 更新或发现旧格式标记时，清空 OTA 目录、marker 和 MMKV key。

## 原生校验

`MainApplication.kt` 读取 `filesDir/ota_version`：文件不存在使用内置 bundle；按 `|` 分割必须恰好两段；APK 版本不匹配时删除 marker；通过后才加载 `filesDir/ota/{code}/index.android.bundle`。

## UI

`OTAListScreen` 展示 `version.json` 中的 OTA 列表并标记当前 `getCurrentOTAVersionCode()`；`UpdateCard` 查找比当前 APK 新的完整版本，用 `useDownloadApk` 下载到 `CacheDir/gxu_tool_update.apk`，再触发 `actionViewIntent`；`VersionListScreen` 展示完整版本历史。

## 验证

执行 `pnpm build-ota`，托管 `version.json`，安装旧 APK 后启动并重启，确认 `DocumentDir/ota/` 中的 bundle 被原生加载；JS 侧再运行 `npx tsc --noEmit`。
