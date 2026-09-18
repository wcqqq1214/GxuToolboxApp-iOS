---
type: auth
title: 统一认证
description: CA 单点登录以及 PEC、xlzxms 服务认证。
tags: [CA, SSO, 统一认证]
---

# 统一认证

`unifiedMachine` 和 `unifiedAdapter` 负责统一认证状态；底层实现仍在 `src/js/auth/auth.ts` 的 `authApi`。

CA 登录先访问 `ca.gxu.edu.cn:8443/zfca`，再按目标服务执行 SSO。物理实验 PEC 使用 `caslogin.aspx`，工程训练 xlzxms 使用 SSO 获取 Authorization Token。服务 Cookie/Token 不能与教务或考勤账号混用。
