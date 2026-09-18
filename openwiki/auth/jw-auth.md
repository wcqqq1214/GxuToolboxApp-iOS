---
type: auth
title: 教务认证
description: JwMachine、教务 Cookie 和远程/本地网关。
tags: [教务, JW, Cookie]
---

# 教务认证

`src/core/auth/Jw/JwMachine.ts` 通过 `JwAuthClient` 读取和保存教务账号。`ensureJwAuthenticated()` 是 feature API 进入教务数据的统一前置检查。

`JwAuthClient` 负责获取公钥、RSA 登录、Token 检查、用户信息和清理会话；登录成功后提取 `JSESSIONID`、`route`，并同步给自建后端。

`src/core/gateway/jw/run.ts` 按 `src/core/gateway/jw/mode.ts` 在远程代理和本地教务请求之间切换。`local_only`、`remote_only` 和默认自动模式的失败回退规则必须保持一致。
