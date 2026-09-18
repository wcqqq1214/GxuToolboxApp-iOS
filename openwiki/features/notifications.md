---
type: feature
title: 调课、调休与假期
description: 解析调课公告、应用调休规则，并在课表中显示假期。
tags: [调课, 调休, 假期, 通知]
---

# 调课、调休与假期通知

## 调课公告

`features/notification/screen/RescheduleNotificationScreen.tsx` 读取教务公告，并用正则解析原教师、原周次、原星期、原节次、原地点、课程、新教师、新周次、新星期、新节次和新地点等字段。

## 调休规则

`features/courseSchedule/hooks/detail/useShift.ts` 从 `file.unde.site` 获取远程时间调整规则，`applyShift` 根据工作日/休息日配对移动或裁剪课表项目。

## 假期

`features/holidays/screen/HolidayScreen.tsx` 提供假期安排页面，`useHoliday` 生成课表需要的假期区间。假期数据属于展示辅助信息，不应覆盖课程原始数据。
