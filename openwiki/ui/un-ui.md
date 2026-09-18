---
type: component-library
title: un-ui 组件库
description: src/components/un-ui 下的 React Native 组件及其导出入口。
tags: [ui, components, un-ui, react-native]
---

# un-ui 组件库

`src/components/un-ui/` 是应用内部 UI 基础库，在 React Native 和 `@rneui/themed` 之上统一布局、文字、表格和底部弹层行为。

## 导出面

`src/components/un-ui/index.ts` 以具名导出提供：

| 导出 | 文件 | 用途 |
|---|---|---|
| `Flex`、`FlexProps` | `Flex.tsx` | Flex 布局容器 |
| `Icon`、`UnIconProps` | `Icon.tsx` | 图标封装 |
| `NumberInput` | `NumberInput.tsx` | 加减数字输入 |
| `UnBottomSheet` | `UnBottomSheet.tsx` | 底部弹层 |
| `UnRefreshControl` | `UnRefreshControl.tsx` | 下拉刷新 |
| `UnTermSelector` | `UnTermSelector.tsx` | 学年/学期选择 |
| `UnText`、`UnCard` | `UnText.tsx`、`UnCard.tsx` | 文字与卡片 |
| `UnTooltip` | `UnTooltip.tsx` | 提示框 |
| `UnTable` 及列类型 | `UnTable.tsx` | 表格 |
| `UnJsonEditor` 及类型 | `UnJsonEditor.tsx` | JSON 调试编辑 |
| `UnPressable` | `UnPressable.tsx` | 可按压容器 |
| `vw`、`vh` | helper | 按窗口比例计算尺寸 |

`ColorPicker`、`UnDateTimePicker`、`UnOption`、`UnPicker`、`UnSectionList`、`UnSlider`、`UnToast` 没有进入 barrel，需要按文件路径直接引用。

## 约定

复杂组件通常带同目录 `.md` 文档，简单组件使用 JSDoc，仍有少数组件没有说明。业务代码优先从 `@/components/un-ui` 导入，非 barrel 组件才直接引用文件。

## 主要使用方

`UnTermSelector` 服务课表、成绩、考试页面；`UnTable` 服务成绩/GPA 表；`UnJsonEditor` 是调试入口；`Flex` 是个人信息和设置页的常用布局原语。

相关：[主题系统](./theming.md)。
