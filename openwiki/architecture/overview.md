---
type: architecture
title: 架构总览
description: 应用结构、技术栈、目录边界以及外部数据到稳定模型的流程。
tags: [架构, React Native, 数据流]
---

# 架构总览

西大工具箱是 Android-only 的 React Native 0.84、React 19、TypeScript 5.9 应用。它把教务、统一认证、考勤、OA、物理实验、工程训练和教师信息等互相独立的系统聚合到一个 App，并转换成页面和桌面 Widget 使用的稳定模型。

主要入口是 `index.js`、`App.tsx` 和 `src/screens/Root.tsx`。新功能原则上放在 `src/features/` 和 `src/core/`；`src/screens`、`src/js`、`src/class`、`src/type` 是仍在使用的遗留区。

外部数据先经过 `gxu-tool-adapters/jw` 或 feature 本地的 Zod schema，再交给 hook、repository 和 UI。页面不应直接访问 HTTP、Cookie、SQL 或外部原始字段。
