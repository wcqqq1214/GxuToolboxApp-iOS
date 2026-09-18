---
type: auth
title: 账号与凭据
description: 各校内系统账号的保存、加载、切换和清除。
tags: [账号, 凭据, 存储]
---

# 账号与凭据

`src/js/mgr/user.ts` 的 `userMgr` 是旧账号 key-value 层，管理教务、统一认证、考勤和问卷系统账号。新认证 machine 通过它实现 `loadAccount`、`saveAccount` 和 `clearAccount`。

账号页面位于 `screens/setting/account/`。切换账号后必须清理或重新加载依赖学号的数据。当前 `examScore` 没有 `studentId`，缓存可能跨账号污染；`examInfo` 和 `userProfiles` 已按学号隔离，修改时应保持这种边界。
