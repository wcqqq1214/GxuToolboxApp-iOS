# 西大工具箱-移动教务

<div align="center">

广西大学 XCPC 技术组
<br>

<div>
<img src="https://img.shields.io/badge/Android-3DDC84?style=flat&logo=android&logoColor=white" alt="platform">
<img src="https://img.shields.io/badge/Version-2.1.2_beta-3B82F6?style=flat" alt="version">
<img src="https://img.shields.io/badge/React_Native-0.84-20232A?style=flat&logo=react" alt="react-native">
<img src="https://img.shields.io/badge/TypeScript-5.9-3178C6?style=flat&logo=typescript&logoColor=white" alt="typescript">
</div>

<br>

<a href="https://tooldoc.gxutech.xyz">使用文档</a> ｜
<a href="best_practice.md">开发指南</a> ｜
<a href="https://gitlab.unde.site/gxutool/gxu_tool_app/-/issues">问题反馈</a> ｜
<a href="#贡献--社区">加入公测</a>

</div>

---

## 目录

- [功能特性](#功能特性)
- [开发背景](#开发背景)
- [快速开始](#快速开始)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [文档](#文档)
- [贡献 & 社区](#贡献--社区)
- [致谢](#致谢)

---

## 功能特性

| | | |
|---|---|---|
| 🔐 **统一认证** | 一个账号打通教务平台、统一认证、考勤系统。一次登录，全平台畅行。 |
| 📅 **智能课表** | 自动导入课表、冲突检测、周视图切换，一键导出至 WakeUp。 |
| 📝 **考勤查询** | 课表与考勤同屏呈现，登录即查（需校园网）。 |
| 📊 **成绩绩点** | 自动获取考试成绩、学分统计、绩点计算。 |
| ✨ **一键评教** | 录制一次模板，自动批量完成评教，告别期末重复劳动。 |
| 🧩 **桌面小组件** | Android 桌面课表 widget，解锁手机即见今日课程。 |
| 🎨 **纯净免费** | TypeScript 编写，开源、零广告、无跟踪，西大人自己的工具。 |

---

## 开发背景

> [!NOTE]
> GXU 的教务平台、文件系统、考勤系统各自独立鉴权，学生在三个平台间来回切换；第三方课表 App 逐步内置广告且无法适配西大特有功能。

| 痛点 | 说明 |
|------|------|
| 登录割裂 | 三个业务各自鉴权，反复登录、反复跳转 |
| 操作繁琐 | 查课表、查成绩要翻多层页面，手机浏览器体验差 |
| 考勤分散 | 考勤需单独登录小程序，无法和课表联动查看 |
| 广告干扰 | 第三方课表 App 陆续加广告，影响使用 |

西大工具箱把这些分散的系统**整合到一个 App 里**，让教务查询像刷手机一样自然。

---

## 快速开始

> 项目仅支持 **Android** 平台。

**环境要求**

- **Node.js** ≥ 18
- **pnpm** ≥ 10
- **Android Studio** (SDK 36)
- **JDK** ≥ 17

<details>
<summary>📋 完整环境配置</summary>

参考 [React Native 环境搭建指南](https://reactnative.dev/docs/set-up-your-environment)，确保 Android SDK 36 和 JDK 17 已正确安装。

</details>

```bash
# 1. 克隆仓库
git clone git@gitlab.unde.site:gxutool/gxu_tool_app.git
cd gxu_tool_app

# 2. 安装依赖
pnpm install

# 3. 启动 Metro（终端 1）
pnpm start

# 4. 运行到设备（终端 2）
pnpm android
```

---

## 技术栈

| 层级 | 选型 | 说明 |
|------|------|------|
| 框架 | React Native 0.84 + React 19 | 跨平台 UI 框架 |
| 语言 | TypeScript 5.9 | 类型安全 |
| UI 组件 | @rneui/themed 5.x | 主题化组件库 |
| 导航 | React Navigation 7.x | Stack + Tab 导航 |
| 状态管理 | Zustand 5.x | 轻量响应式 |
| 数据校验 | Zod 4.x | 外部数据 Schema 校验 |
| 网络 | Axios 1.x（3 实例） | 三套鉴权独立拦截 |
| 数据库 | OP-SQLite 17.x | 结构化本地存储 |
| KV 存储 | react-native-mmkv 4.x | 配置与缓存 |
| 表单 | react-hook-form 7.x | 高性能表单 |
| 小组件 | react-native-android-widget | 桌面课表 widget |
| 构建 | Gradle (SDK 36) / Metro | — |
| 部署 | Docker (Node 20 + JDK 17) | CI/构建环境 |

---

## 项目结构

```
gxu_tool_app/
├── android/                 # Android 原生工程 (Gradle)
├── src/
│   ├── core/                # 基础设施 — 认证、HTTP、数据库
│   ├── features/            # 功能模块（新代码入口）
│   │   ├── courseSchedule/  #   课表
│   │   ├── examInfo/        #   考试信息
│   │   ├── examScore/       #   成绩查询
│   │   ├── evaluation/      #   自动评教
│   │   ├── attendance/      #   考勤
│   │   └── documents/       #   文件系统
│   ├── components/un-ui/    # 自研 UI 组件库
│   ├── screens/             # 页面
│   ├── route/               # 导航配置
│   └── widget/              # 桌面课表小组件
├── scripts/                 # 辅助脚本
├── best_practice.md         # 工程规范
└── package.json
```

> 开发前请先阅读 [best_practice.md](best_practice.md)，了解数据流规则、认证边界和代码准入标准。

---

## 文档

- **使用文档** · [tooldoc.gxutech.xyz](https://tooldoc.gxutech.xyz)
- **开发指南** · [best_practice.md](best_practice.md) — 数据流、认证、持久化等工程规范
- **环境搭建** · [React.md](React.md) — 项目目录说明与调试技巧

---

## 贡献 & 社区

由 **广西大学 XCPC 技术组** 维护，欢迎校内同学参与。

- 📱 公测群 **580048805**（入群获取安装包）
- 🐛 [GitLab Issues](https://gitlab.unde.site/gxutool/gxu_tool_app/-/issues) 反馈问题
- 📖 提交前对照 [Code Review Checklist](best_practice.md#code-review-checklist)

---

## 致谢

广西大学 XCPC 技术组全体成员 · 参与公测的同学们 · [React Native](https://reactnative.dev) 及所有开源依赖的作者
