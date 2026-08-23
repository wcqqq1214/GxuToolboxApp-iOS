---
type: architecture
title: 构建与工具链
description: Babel、Metro、pnpm、脚本、Docker 和验证方式。
tags: [构建, Babel, Metro, pnpm, 测试]
---

# 构建与工具链

`babel.config.js` 用 `module-resolver` 将 `@/` 映射到 `src`，用 `inline-import` 内联 `.sql` 迁移文件；`tsconfig.json` 必须同步维护同一 alias。`metro.config.js` 将 `cheerio` 解析到 `react-native-cheerio`，评教、统一认证、个人信息和问卷解析都依赖这个 shim。

主要命令：

- `pnpm start`：通过 adb reverse 在 18081 端口启动 Metro；
- `pnpm android`：构建并安装 Android 调试包；
- `pnpm lint`：运行 ESLint；
- `pnpm pull-db`：从调试应用拉取 SQLite；
- `pnpm build-ota`：生成 OTA Bundle 和版本元数据；
- `npx tsc --noEmit`：类型检查。

根目录 Dockerfile 使用 yarn、错误的工作目录和旧 SDK，当前不可作为发布构建入口。仓库没有有效的 App 行为测试套件，验证应结合类型检查、Metro 构建和真机流程；adapter 自带的 parser 测试只覆盖部分标准化逻辑。
