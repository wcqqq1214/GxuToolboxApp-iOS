---
type: feature
title: 反馈与事件
description: 用户反馈以及轻量应用事件上报。
tags: [反馈, 事件, 后端]
---

# 反馈与事件

## 用户反馈

`features/feedback` 包含反馈填写、反馈列表和反馈详情页面。表单由 `feedbackSchema.ts` 约束，接口位于 `features/backend/api/feedback.ts`，发送到自建后端的 `/feedback`。

## 事件上报

`features/feedback/api/event.ts` 提供 `submitEvent`、`openAppEvent` 和 `loginJwEvent`。事件用于记录打开 App、教务登录成功等行为，属于非关键副作用，失败不能阻塞启动或主业务。

## 入口

RootStack 中注册了 `feedback`、`feedbackList` 和 `feedbackDetail`。页面应通过 hook/API 获取数据，不应直接接触 HTTP 或存储细节。
