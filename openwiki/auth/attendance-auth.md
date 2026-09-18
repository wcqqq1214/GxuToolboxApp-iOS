---
type: auth
title: 考勤认证
description: 考勤系统验证码登录、AES 密码加密和 Token 管理。
tags: [考勤, 验证码, Token]
---

# 考勤认证

`attendanceMachine` 使用 `attendanceAdapter` 和 `attendanceAuthApi`。考勤登录需要验证码，不能像教务认证一样静默重登录；`loginWithAccount` 在验证码缺失时必须保持失败。

密码通过 AES-ECB/PKCS7 处理，验证码图片由 `attendanceAuthApi.getCaptchaImage()` 获取，登录成功后 Token 存储在 `attendanceSystemLoginRes`。页面入口是 `AttendanceSystemAccountScreen.tsx`，快捷登录组件是 `AttendanceQuickLogin.tsx`。
