---
type: feature
title: 学校文档
description: 通过 OA 文件系统浏览、搜索和查看学校文档。
tags: [文档, OA, 文件]
---

# 学校文档

## 功能

入口是 `features/documents/screen/MainScreen.tsx`，请求封装在 `features/documents/api/index.ts`。页面支持文件列表、关键词搜索、分页和文件详情。

## 数据与认证

OA 服务地址是 `https://oa.gxu.edu.cn/api/gxuoa`，使用 Bearer JWT。登录信息由 `userMgr.wjxt` 管理，API 层负责附加 Token，并在 401 时执行一次重新认证和重试。

页面只负责显示和交互；文件请求、Token、错误转换都属于 API 层。底层失败应交给页面展示一次错误，不应在 API 内直接弹 Toast。

## 相关接口

- `POST /wenjian/page`：按页获取文件列表。
- `GET /wenjian/detail`：按文件 ID 获取详情。
- `GET /document-search/search`：按标题关键词搜索文件。
