---
type: infrastructure
title: 存储（AsyncStorage / MMKV / Zustand）
description: 三层持久化、key 清单，以及遗留和迁移中的数据。
tags: [core, storage, cache, mmkv, asyncstorage]
---

# 存储（AsyncStorage / MMKV / Zustand）

结构化数据使用 SQLite；其余状态分三层：

| 层 | 包装 | 特性 | 常见用途 |
|---|---|---|---|
| AsyncStorage via `react-native-storage` | `src/core/store.ts` | 异步、带缓存 | 账号、token、配置、遗留缓存 |
| MMKV | `src/store/mmkv.ts` | 同步 | 课表、考试、考勤、物理实验热缓存和 OTA marker |
| Zustand | `src/features/*/stores`、`src/hooks` | 内存 | 从上面两层 hydrate 的 UI 状态 |

## AsyncStorage 重要 key

`userAccount`、`userAuthAccount`、`attendanceSystemAccount`、`attendanceSystemLoginRes`、`wjxtAccount`、`wjxtToken` 保存三类登录信息；`AttendanceSystemMenuData` 保存考勤日历；`userConfig`、`courseDataStore`、`conflictCourseStore` 保存配置和课表渲染状态；`practiceSchedule`、`courseScheduleSetting`、`courseScheduleStore`、`engTrainingExpList` 是功能缓存；`@EvaluationTemplate` 是旧评价模板；`userInfo` 是遗留个人资料桥。

`courseRes` 目前只读不写：小组件 `src/js/nextCourses.ts` 和设置页仍读取它，新课表链路已经改写 MMKV `personalSchedule`。新安装没有旧缓存时小组件可能为空。

## MMKV key

- `personalSchedule`：`useBaseCourse.ts` 写入的 adapter `Schedule`。
- `originalExamList`、`examStartDay`：考试原始数据和起始日。
- `originalAttendanceList`、`attendanceStartDay`：考勤原始数据和起始日。
- `originalPhyExpList`：物理实验原始数据。
- `ota_version_code`、`ota_app_version_code`：OTA bundle 与 APK 版本。

文件层还包括 `DocumentDir/ota/{versionCode}/index.android.bundle` 和 `filesDir/ota_version`（格式 `otaVersionCode|appVersionCode`）。

## 遗留与加载模式

`courseScheduleSetting`、`courseScheduleStore` 属于旧 `src/js/jw/course.ts`，不应当当作新 `features/courseSchedule` 的来源；`userInfo` 也是旧桥，现代路径是 `userProfiles` 表和 `userProfileServer.syncInfo`。

`useUserConfig`、`useCourseData` 的 `init()` 都是从 AsyncStorage 读原始对象、与默认值 `deepMerge` 后写入 Zustand；`Root.tsx` 触发它们但不等待。
