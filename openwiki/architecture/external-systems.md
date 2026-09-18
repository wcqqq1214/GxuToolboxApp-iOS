---
type: architecture
title: 外部系统
description: App 访问的校内系统、地址、认证方式和代码入口。
tags: [外部系统, API, 认证]
---

# 外部系统

| 系统 | 地址 | 认证 | 主要代码 |
|---|---|---|---|
| 教务 jwxt | `jwxt2018.gxu.edu.cn/jwglxt` | `JSESSIONID` Cookie | `src/core/http.ts`、`src/core/auth/Jw`、`src/js/jw` |
| 统一认证 CA | `ca.gxu.edu.cn:8443/zfca` | RSA + CAS SSO | `src/js/auth/auth.ts` |
| 考勤 ykt | `yktuipweb.gxu.edu.cn` | Token | `src/features/attendance`、`src/core/auth/attendance` |
| 教师 prof | `prof.gxu.edu.cn` | 公开 API | `src/js/info/teacherInfo.ts` |
| OA | `oa.gxu.edu.cn/api/gxuoa` | Bearer JWT | `src/features/documents` |
| 自建后端 | `api.tool.gxutech.xyz` | 与教务共享会话 Cookie | `src/features/backend/api` |
| OTA 文件站 | `file.unde.site/GxuToolApp` | 无 | `src/core/ota.ts` |

其他系统包括问卷 wjxt、物理实验 PEC、工程训练 xlzxms 和 ACM。完整的反向接口记录在 `docs/api-docs/`。

自建后端主要代理 `/jw/schedule/*`、`/jw/score`、`/jw/exam`、`/jw/evaluation`、`/jw/selected-courses`、`/jw/profile` 和 `/feedback`。后端使用请求中的教务 Cookie 访问 jwxt，客户端通过 `backendHttp` 调用。
