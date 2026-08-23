---
type: feature
title: 其他工具
description: 教师查询、地图导航、教学楼地图、Widget 预览和实践课查询。
tags: [教师, 地图, Widget, 实践课]
---

# 其他工具

## 教师信息

`src/js/info/teacherInfo.ts` 访问 `https://prof.gxu.edu.cn/backend/openapi/openSearch`：`getBaseInfo` 调用 `/findByCondition`，`getInfoByFirstLetter` 按姓氏首字母查询，`getDetailInfo` 调用 `/getTeachInfoByGH` 获取详情。页面是 `TeacherInfoScreen.tsx` 和 `DetailInfoScreen.tsx`。

## 地图与教学楼

`src/js/pos.ts` 生成高德、百度地图 Deep Link，并由 `MapPickerHost` 选择已安装的地图应用。教学楼地图位于 `src/screens/tool/other/TeachingBuildingMap/`，数据目前是本地静态数据。

## Widget 与实践课

`WidgetPreviewScreen.tsx` 用于预览课表 Widget。物理实验入口是 `PhyExpScreen.tsx`，工程训练入口是 `EngTrainingScheduleScreen.tsx`；二者分别依赖 PEC 和 xlzxms 的单点登录。

开发测试入口是 `src/features/TestPage.tsx`，路由名为 `TestPage`。
