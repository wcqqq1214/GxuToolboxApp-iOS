---
type: feature
title: 课表 UI 组件
description: ScheduleTableItem 的卡片、弹层、渲染器，以及旧查询和导出页面。
tags: [course-schedule, ui, components, screens]
---

# 课表 UI 组件

现代组件位于 `src/features/courseSchedule/components`，通用/遗留渲染器位于 `src/components/tool/infoQuery/courseSchedule`。

## 现代组件

`ScheduleCard` 负责首页分页、底部弹层、详情和冲突；`NewCourseItem`、`NewExamItem`、`HolidayItem`、`StackCourseItem` 绘制不同 item；`PracticalCourseList` 展示实践课；`CourseDetail`、`AuthStatusSection`、`AttendanceStateIcon`、`ConflictCourseList` 提供详情、认证提示、考勤图标和冲突列表。

## 通用渲染器

`TimeScheduleView`/`TimeSchedule` 是周视图，`CanvasSchedule` 是 canvas 版本，`CourseItem` 绘制单块课程，`CollapsedInfo` 汇总多条，`CourseCardSetting` 修改显示项，`ScheduleShareSheet` 导出/分享，`TeacherInfoSheet` 展示教师，`ExamDetail` 展示考试详情。`ChooseTerm` 是共用学年学期选择器。

## 日程编辑

`ScheduleEdit` 路由编辑 `userConfig.activity` 中按 `{year, term}` 保存的 `IActivity`（名称、描述、1-13 节、1-20 周、星期、颜色），使用 `TimeScheduleView` 预览并通过 `update("activity", ...)` 持久化。当前活动只在编辑页预览，首页不显示。

## 遗留查询与导出

`courseScheduleQuery` 和 `ExportScheduleScreen` 仍在 `src/screens/tool/jw/infoQuery/courseSchedule`：后者生成 `export_schedule.html`，调用 `OpenWithModule.openFile`，再以 Android `ACTION_VIEW` chooser 打开。两个页面仍依赖 `courseRes`/旧缓存，不要把新逻辑继续放入旧路径。

验证：`npx tsc --noEmit`、`pnpm start`，检查卡片、冲突堆叠和导出 chooser。
