---
type: reference
title: 主题与共享 UI 工具
description: 主题生成、用户配置颜色，以及共享颜色/RSA/HTML 工具。
tags: [ui, theming, color, rneui, shared]
---

# 主题与共享 UI 工具

主题代码位于 `src/shared/`，由 `src/screens/Root.tsx` 和 `useUserConfig` 使用。

## 主题流水线

`src/shared/theme.ts`：

- `theme` 是基于 `@rneui/themed` 的 `createTheme` 默认主题，设置 `Divider`、`Slider` 和字号 12 的 `Text`。
- `DefaultUserTheme` 为 `{bgUrl: "", bgOpacity: 100, ripple: {color: "gray"}, primaryColor: "#48A6EF"}`。
- `generateUiTheme(config, colorScheme)` 将基础主题与 `mode`、`lightColors.primary`、`darkColors.primary` 合并，颜色来自 `config.theme?.primaryColor`，缺省为 `#48A6EF`。

`Root.tsx` 使用当前 `useUserConfig` 和系统 `colorScheme` 包裹 `ThemeProvider`。

## 用户配置

`src/hooks/useUserConfig.ts` 是 Zustand store，底层 key 为 `react-native-storage` 的 `userConfig`（见 `src/core/store.ts`）。`init()` 读取并与 `defaultUserConfig` 深合并；`update(k, v)` 修改并持久化；`load`、`save`、`remove` 直接透传存储层。配置类型和默认值在 `src/type/IUserConfig.ts`。

## 颜色与共享工具

- `src/shared/color.ts` 的 `BaseColor` 保存 HTML 标准色到 hex 的映射，`Color` 负责颜色解析和操作，课表颜色系统依赖它。
- `src/shared/rasPassword.js` 提供 JW/CA 登录 RSA 加密。
- `src/shared/domParser.ts` 提供个人信息、评价详情使用的 HTML 节点辅助。
- `src/utils/objectUtils.ts` 的 `deepMerge` 同时服务主题和配置合并。

相关：[un-ui 组件库](./un-ui.md)。
