---
type: auth
title: 认证总览
description: 统一认证状态机以及教务、统一认证、考勤三套账号系统。
tags: [认证, 状态机, 账号]
---

# 认证总览

通用实现是 `src/core/auth/createAuthCore.ts`。状态依次为 `NoAccount`、`HasAccountNotAuthenticated`、`Authenticated`，`refreshToken` 使用 `pendingAuth` 合并并发刷新。

当前有三套机器：`JwMachine`、`unifiedMachine`、`attendanceMachine`。新功能应通过对应 machine 和 `ensureJwAuthenticated()` 进入认证边界，不要直接调用旧的 `src/js/jw/jwxt.ts`。

旧的 `src/js/auth/*` 与新的 `src/core/auth/*` 仍然并存。迁移时必须先确认调用方使用的是哪一条 Cookie/Token 链路，避免重复登录和会话竞争。
