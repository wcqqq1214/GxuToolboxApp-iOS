---
type: feature
title: 个人信息
description: 获取、显示和同步当前教务账号的个人资料。
tags: [个人信息, 教务, profile]
---

# 个人信息

页面入口是 `features/personalInfo/screen/PersonalInfo.tsx`。它通过个人信息 API 获取当前账号资料，展示姓名、学号、学院等字段。

现代同步路径由 `core/repo/userProfileServer.ts` 和 `core/repo/userProfileRepo.ts` 负责，数据库操作不应出现在组件中。个人资料按学号隔离；账号切换时必须重新确认当前账号，不能直接复用旧用户状态。
