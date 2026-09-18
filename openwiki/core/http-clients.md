---
type: infrastructure
title: HTTP 客户端
description: jwxt、自建后端、OA 和 ACM 的 axios 实例、认证约定及已知偏差。
tags: [core, http, axios, infrastructure]
---

# HTTP 客户端

应用有四个 axios 面：

## `src/core/http.ts`：jwxt

默认导出的 `http` 指向 `https://jwxt2018.gxu.edu.cn/jwglxt`，使用 `application/x-www-form-urlencoded`、`withCredentials: true`、`maxRedirects: 0`。`urlWithParams` 会删除 `undefined` 后拼接查询参数；`objectToFormUrlEncoded` 递归编码数组（`prefix[i]`）、对象（`prefix.key`）和标量，丢弃 `undefined`/`null`，用于包含嵌套 `queryModel` 的 POST。

已知偏差：请求拦截器在缺账号时直接 Toast，底层不应承担 UI；响应错误拦截器把 `error` 当 fulfilled 值返回，而不是 `Promise.reject(error)`。因此失败请求会 resolve 为 `AxiosError`，调用方的 `catch` 收不到真实拒绝，旧接口只能通过 `res.data` 类型探测后自行走失败分支。新代码不要复制这个行为。

## `src/features/backend/api/index.ts`：自建后端

`backendHttp` 指向 `http://api.tool.gxutech.xyz`，发送 JSON、`withCredentials: true`、超时 10 秒，并正确 reject。它是当前教务查询代理的现代入口。

## `src/features/documents/api/index.ts`：OA

`oaHttp` 指向 `https://oa.gxu.edu.cn/api/gxuoa`。除 `/auth/login` 外，请求会附加 `userMgr.wjxt.getToken()` 的 Bearer token；401 时使用保存的账号单次重新登录，缓存 `accessToken` 后按 `_retry` 标记重试原请求。导出的 `index` 提供 `login`、`getFileList`、`getFileDetail`、`testToken`、`searchFile`。

## `src/js/be.ts`：ACM

遗留 axios 实例指向 `acm.gxu.edu.cn/gxuicpc`，当前没有接入具体调用。

## 验证

没有拦截器单测。可在真机登录 JW、打开 OA 文件列表验证；后端客户端的 reject 行为是新客户端应遵循的模式。
