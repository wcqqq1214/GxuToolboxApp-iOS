# GxuToolApp — 网络 API 接口文档

> 历史 RN 接口索引（v2.1.3 beta）。其中的 `src/` 路径对应上游 RN 源码。iOS 的接口调用以 `Packages/` 中的 Swift 实现为准。
> 文档生成日期：2026-07-31

---

## 📋 目录

| # | 系统 | 域名 | 功能 |
|---|------|------|------|
| 1 | [教务系统 (jwxt)](#1-教务系统-jwxt) | `jwxt2018.gxu.edu.cn` | 课表、成绩、选课、个人信息 |
| 2 | [统一认证系统 (CA)](#2-统一认证系统-ca) | `ca.gxu.edu.cn` | SSO 统一登录认证 |
| 3 | [考勤系统 (Attendance)](#3-考勤系统-attendance) | `yktuipweb.gxu.edu.cn` | 考勤打卡、出勤统计 |
| 4 | [教师信息查询 (prof)](#4-教师信息查询-prof) | `prof.gxu.edu.cn` | 教师信息检索 |
| 5 | [OA 文件系统 (OA)](#5-oa-文件系统-oa) | `oa.gxu.edu.cn` | 公文文件查阅 |
| 6 | [问卷系统 (wjxt)](#6-问卷系统-wjxt) | `wjxt.gxu.edu.cn` | 待办问卷查看 |
| 7 | [物理实验平台 (PEC)](#7-物理实验平台-pec) | `pec.gxu.edu.cn` | 物理实验课管理 |
| 8 | [工程训练中心 (xlzxms)](#8-工程训练中心-xlzxms) | `xlzxms.gxu.edu.cn` | 金工实训课表 |
| 9 | [ACM 竞赛系统](#9-acm-竞赛系统) | `acm.gxu.edu.cn` | ACM 竞赛数据 |
| 10 | [自建后端 API](#10-自建后端-api) | `api.tool.gxutech.xyz` | 成绩代理、反馈、埋点 |
| 11 | [OTA 热更新](#11-ota-热更新) | `file.unde.site` | 版本检查与热更新 |
| 12 | [其他辅助接口](#12-其他辅助接口) | 多个 | WebView 跳转、页面导出 |

---

## 1. 教务系统 (jwxt)

### 基础信息

| 项目 | 内容 |
|------|------|
| **baseURL** | `https://jwxt2018.gxu.edu.cn/jwglxt` |
| **Content-Type** | `application/x-www-form-urlencoded; charset=UTF-8` |
| **认证方式** | Cookie (JSESSIONID) |
| **核心文件** | `src/core/http.ts` |

### 接口列表

#### 1.1 课表相关

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `POST` | `/kbcx/xskbcx_cxXsgrkb.html` | **获取个人课表** | `src/js/jw/course.ts:218` |
| `POST` | `/kbdy/bjkbdy_cxBjkbdyTjkbList.html` | **获取班级课表列表** | `src/js/jw/course.ts:256` |
| `POST` | `/kbdy/bjkbdy_cxBjKb.html` | **获取班级课表内容** | `src/js/jw/course.ts:287` |

**参数说明**（个人课表）：
- `xnm` — 学年（如 `2024`）
- `xqm` — 学期（如 `3` 表示第一学期）

**参数说明**（班级课表）：
- `xnm` — 学年
- `xqm` — 学期
- `njdm_id` — 年级
- `jg_id` — 学院ID
- `zyh_id` — 专业ID
- `bh_id` — 班级ID

#### 1.2 成绩相关

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `POST` | `/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005` | **获取考试成绩** | `src/features/examScore/api/index.ts:60` |

**参数说明**：
- `xnm` — 学年
- `xqm` — 学期
- `queryModel.showCount` — 每页条数
- `queryModel.currentPage` — 当前页
- `queryModel.sortName` / `sortOrder` — 排序字段/方向

#### 1.3 选课相关

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `POST` | `/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html` | **获取选课列表** | `src/js/jw/course.ts:359` |

**参数说明**：
- `xkxnm` — 选课学年
- `xkxqm` — 选课学期
- `kklxdm` — 课程类型代码
- `kspage` / `jspage` — 页码
- `xkkz_id` — 选课控制ID

#### 1.4 登录认证相关

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `GET` | `/xtgl/login_getPublicKey.html` | **获取 RSA 公钥** | `src/core/auth/Jw/JwAuthClient.ts:103` |
| `POST` | `/xtgl/login_slogin.html` | **普通登录** | `src/core/auth/Jw/JwAuthClient.ts:107` |
| `POST` | `/xtgl/login_slogin.html` | **RSA 加密登录** | `src/core/auth/Jw/JwAuthClient.ts:125` |

#### 1.5 个人信息

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `POST` | `/xsxxxggl/xsgrxxwh_cxXsgrxx.html?gnmkdm=N100801` | **获取个人信息** | `src/core/auth/Jw/JwAuthClient.ts:145` |

---

## 2. 统一认证系统 (CA)

### 基础信息

| 项目 | 内容 |
|------|------|
| **域名** | `https://ca.gxu.edu.cn:8443/zfca` |
| **备用域名** | `http://ca.gxu.edu.cn:81/zfim` |
| **认证方式** | RSA 加密密码 + CAS SSO |
| **核心文件** | `src/js/auth/auth.ts` |

### 接口列表

| 方法 | 完整 URL | 功能 | 文件 |
|------|---------|------|------|
| `GET` | `https://ca.gxu.edu.cn:8443/zfca/v2/getPubKey` | **获取 RSA 公钥**（返回 exponent + modulus） | `auth.ts:20` |
| `GET` | `https://ca.gxu.edu.cn:8443/zfca/login` | **获取登录页**（提取 execution 参数） | `auth.ts:46` |
| `POST` | `https://ca.gxu.edu.cn:8443/zfca/login?service=...` | **提交登录**（RSA 加密密码） | `auth.ts:51` |
| `GET` | `http://ca.gxu.edu.cn:81/zfim/application/home/getYyfz.zf` | **检测登录状态** | `auth.ts:88` |
| `GET` | `https://ca.gxu.edu.cn:8443/zfca/logout?service=...` | **登出** | `auth.ts:94` |

**登录流程说明**：
1. 先调用 `getPubKey` 获取 RSA 公钥
2. 再请求 `login` 页面，从 HTML 中提取 `execution` 参数
3. 密码反转后用 RSA 公钥加密
4. 提交 `username` + 加密密码 + `execution` 到 `login` 接口

---

## 3. 考勤系统 (Attendance)

### 基础信息

| 项目 | 内容 |
|------|------|
| **baseURL** | `https://yktuipweb.gxu.edu.cn` |
| **认证方式** | Token（`Authorization: Token xxx`） |
| **核心文件** | `src/js/auth/attendanceSystem.ts`、`src/features/attendance/api/index.ts`、`src/core/auth/attendance/attendanceAuthApi.ts` |

### 接口列表

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `GET` | `/api/account/getVerify?num=666` | **获取验证码图片**（返回 ArrayBuffer → base64） | `attendanceAuthApi.ts:12` |
| `POST` | `/api/account/loginCheck` | **登录**（AES 加密密码） | `attendanceAuthApi.ts:37` |
| `GET` | `/api/account/getIndexData?rm=SYS004` | **获取首页菜单数据**（含学期日历） | `attendanceSystem.ts:34` |
| `POST` | `/api/personalData/getPersonalData?cal=...&rm=SYS004` | **获取个人考勤记录**（分页） | `attendanceSystem.ts:149` |
| `POST` | `/api/personalData/getPersonalDataCount?cal=...&rm=SYS004` | **获取考勤统计数据** | `attendanceSystem.ts:188` |
| `POST` | `/api/rank/selectByStudent?cal=...&rm=SYS004` | **获取考勤课表** | `attendanceSystem.ts:216` |

**登录参数说明**：
- `client` — 固定值 `web_atd`
- `loginName` — 用户名
- `pwd` — AES/ECB/PKCS7 加密后的密码（密钥：`k;)*(+nmjdsf$#@d`）
- `type` — 固定值 `1`
- `verificationCode` — 验证码

**考勤查询参数**：
- `cal` — 学期日历ID
- `rm` — 固定值 `SYS004`
- `page_index` / `page_size` — 分页
- `search.ksrq` / `search.jsrq` — 日期范围
- `search.courseId` — 课程ID（可选）

---

## 4. 教师信息查询 (prof)

### 基础信息

| 项目               | 内容                                                   |
|------------------|------------------------------------------------------|
| **baseURL**      | `https://prof.gxu.edu.cn/backend/openapi/openSearch` |
| **Content-Type** | `application/json`                                   |
| **核心文件**         | `src/features/teachersInfo/api/index.ts`             |

### 接口列表

| 方法    | 路径                  | 功能              | 文件                |
|-------|---------------------|-----------------|-------------------|
| `GET` | `/findByCondition`  | **按条件查询教师**     | `api/index.ts:32` |
| `GET` | `/getTeachInfoByGH` | **按工号获取教师详细信息** | `api/index.ts:51` |

**查询参数说明**：
- `xm` — 教师姓名
- `indexSearchKey` — 搜索关键词
- `firstLetter` — 姓氏首字母
- `pageNum` / `pageSize` — 分页
- `GH` — 教师工号（详情查询用）

---

## 5. OA 文件系统 (OA)

### 基础信息

| 项目 | 内容 |
|------|------|
| **baseURL** | `https://oa.gxu.edu.cn/api/gxuoa` |
| **认证方式** | Bearer Token（JWT） |
| **核心文件** | `src/features/documents/api/index.ts` |

### 接口列表

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `POST` | `https://oa.gxu.edu.cn/api/gxuoaAuth/gxuoa/auth/login` | **OA 登录** | `documents/api/index.ts:40` |
| `POST` | `/wenjian/page` | **获取文件列表（分页）** | `documents/api/index.ts:92` |
| `GET` | `/wenjian/detail?id=...` | **获取文件详情** | `documents/api/index.ts:112` |
| `GET` | `/document-search/search` | **搜索文件** | `documents/api/index.ts:134` |

**登录参数说明**：
- `Account` — 用户名
- `Password` — 密码

**文件列表参数**：
- `page` / `pageSize` — 分页
- `keyword` — 关键词
- `fileTypeId` — 文件类型ID
- `selectedDepartmentId` — 部门ID
- `keywordType` — 搜索类型，默认 `title`

**搜索参数**：
- `_wv` — 版本号（如 `20250701-2200`）
- `searchType` — 搜索类型（`deptDoc`）
- `keyword` — 关键词
- `keywordType` — 搜索类型（`title`）
- `page` / `pageSize` — 分页

---

## 6. 问卷系统 (wjxt)

### 基础信息

| 项目 | 内容 |
|------|------|
| **baseURL** | `https://wjxt.gxu.edu.cn/` |
| **Content-Type** | `application/x-www-form-urlencoded` |
| **编码** | GB2312（需 iconv 解码） |
| **核心文件** | `src/js/wjxt/api.ts` |

### 接口列表

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `POST` | `/` | **登录**（提交表单） | `wjxt/api.ts:29` |
| `POST` | `Wjxt_UI/qstwj.aspx` | **获取待办问卷列表** | `wjxt/api.ts:39` |

**登录参数说明**：
- `__VIEWSTATE` — ASP.NET 视图状态（固定值）
- `__VIEWSTATEGENERATOR` — 生成器（固定值）
- `userIdCard` — 用户名（身份证号）
- `userPwd` — 密码
- `loginsubmit` — 登录按钮值（`%B5%C7+%C2%BC`）
- `myteip` — IP 地址（固定值 `172.30.135.20--2`）

---

## 7. 物理实验平台 (PEC)

### 基础信息

| 项目 | 内容 |
|------|------|
| **域名** | `https://pec.gxu.edu.cn` |
| **登录入口** | `http://pec.gxu.edu.cn/caslogin.aspx` |
| **核心文件** | `src/js/jw/course.ts` |

### 接口列表

| 方法 | 完整 URL | 功能 | 文件 |
|------|---------|------|------|
| `GET` | `http://pec.gxu.edu.cn/caslogin.aspx` | **CAS 登录入口**（通过统一认证） | `course.ts:323` |
| `POST` | `https://pec.gxu.edu.cn/LMSmini/teacher/UI/wxInterface/syjx.asmx/getRuleManage` | **获取物理实验课列表** | `course.ts:325` |

**实验课参数说明**：
- `page` — 页码
- `limit` — 每页条数

---

## 8. 工程训练中心 (xlzxms)

### 基础信息

| 项目 | 内容 |
|------|------|
| **域名** | `http://xlzxms.gxu.edu.cn` |
| **核心文件** | `src/js/auth/auth.ts`、`src/js/jw/course.ts` |

### 接口列表

| 方法 | 完整 URL | 功能 | 文件 |
|------|---------|------|------|
| `GET` | `http://xlzxms.gxu.edu.cn/api/security-server/dietc/loginsso/student` | **SSO 登录获取学生码** | `auth.ts:108` |
| `POST` | `http://xlzxms.gxu.edu.cn/api/security-server/dietc/sys/authorizing/loginsso` | **获取 Authorization Token** | `auth.ts:120` |
| `GET` | `http://xlzxms.gxu.edu.cn/api/course-newedition-server/course/course/arrange/stuPersonalArrangeTable` | **获取个人工程训练课表** | `course.ts:379` |

**Token 请求参数**：
- `username` — 学生码（从上一步获取）
- `code` — 固定值 `ssocode`
- `queryParam` — 固定值 `queryParam`
- `password` — 固定值 `1`

---

## 9. ACM 竞赛系统

### 基础信息

| 项目 | 内容 |
|------|------|
| **baseURL** | `http://acm.gxu.edu.cn/gxuicpc` |
| **Content-Type** | `application/json; charset=UTF-8` |
| **核心文件** | `src/js/be.ts` |

### 接口列表

| 方法 | 说明 |
|------|------|
| 待补充 | 该 Axios 实例已创建，但具体接口调用位置需进一步确认 |

---

## 10. 自建后端 API

### 基础信息

| 项目 | 内容 |
|------|------|
| **baseURL** | `http://api.tool.gxutech.xyz` |
| **Content-Type** | `application/json` |
| **超时时间** | 10 秒 |
| **认证方式** | Cookie (JSESSIONID，与教务共享) |
| **核心文件** | `src/features/backend/api/index.ts` |

### 接口列表

#### 10.1 成绩相关

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `GET` | `/jw/score` | **获取考试成绩**（代理模式） | `examScore/api/index.ts:33` |
| `GET` | `/jw/score/usual` | **获取平时成绩** | `examScore/api/index.ts:86` |

**考试成绩参数**：
- `pageSize` / `pageNo` — 分页
- `orderBy` / `order` — 排序（默认按考试时间倒序）
- `year` / `term` — 学年学期（可选）

#### 10.2 教务配置

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `POST` | `/jw/login` | **教务系统登录代理** | `core/auth/Jw/JwAuthClient.ts:52` |
| `POST` | `/jw/profile` | **保存教务配置** | `backend/api/profile.ts:4` |
| `GET` | `/jw/profile/startDay` | **获取学期开始日期** | `courseSchedule/repo/startDay.ts:15` |

#### 10.3 反馈系统

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `POST` | `/feedback` | **提交反馈** | `backend/api/feedback.ts:12` |
| `GET` | `/feedback/{userId}` | **获取用户反馈列表** | `backend/api/feedback.ts:16` |

#### 10.4 事件埋点

| 方法 | 路径 | 功能 | 文件 |
|------|------|------|------|
| `POST` | `/event` | **提交事件埋点** | `feedback/api/event.ts:19` |

**埋点参数**：
- `userId` — 用户学号
- `eventName` — 事件名称（如 `login_jw_success`、`open_app`）
- `feature` — 功能模块（如 `login`、`app`）
- `appVersion` — 应用版本号

---

## 11. OTA 热更新

### 基础信息

| 项目 | 内容 |
|------|------|
| **URL** | `https://file.unde.site/GxuToolApp/version.json` |
| **核心文件** | `src/core/ota.ts`、`src/components/UpdateCard.tsx` |

### 接口列表

| 方法 | 完整 URL | 功能 | 文件 |
|------|---------|------|------|
| `GET` | `https://file.unde.site/GxuToolApp/version.json` | **检查版本更新**（OTA + 版本列表） | `ota.ts:22` |

**返回数据结构**：
```json
{
  "beta": [ { "versionCode": 20103, "versionName": "2.1.3", "ota": [...] } ],
  "release": [ { "versionCode": ..., "versionName": "...", "ota": [...] } ]
}
```

**OTA 下载**：通过 `ReactNativeBlobUtil` 下载 bundle 包到本地，下次启动生效。

---

## 12. 其他辅助接口

### 12.1 页面导出 URL（WebView 跳转）

| URL | 用途 | 文件 |
|-----|------|------|
| `https://jwxt2018.gxu.edu.cn/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default` | 个人课表导出（Web 版） | `ExportScheduleScreen.tsx:11` |
| `https://jwxt2018.gxu.edu.cn/jwglxt/kbdy/bjkbdy_cxBjkbdyIndex.html?gnmkdm=N214505&layout=default` | 班级课表导出（Web 版） | `ExportScheduleScreen.tsx:12` |
| `https://yktuipweb.gxu.edu.cn/#/StudentHome` | 考勤系统首页（Web 版） | `AttendanceInfoQueryScreen.tsx:83` |
| `http://xlzxms.gxu.edu.cn/api/security-server/dietc/loginsso/student` | 工程训练 Web 登录 | `EngTrainingScheduleScreen.tsx:63` |
| `https://pec.gxu.edu.cn/Customer/MasterPage/UserCenterPage.html` | 物理实验 Web 页面 | `PhyExpScreen.tsx:55` |
| `https://xywjf.gxu.edu.cn/WebPay/toRecharge` | 缴费充值（注释掉） | `ToolboxIndex.tsx:194` |
| `https://qm.qq.com/q/tVlQHwhwXu` | QQ 群链接 | `SettingIndex.tsx:183` |

### 12.2 静态资源

| URL                                               | 用途        | 文件                                                       |
|---------------------------------------------------|-----------|----------------------------------------------------------|
| `https://prof.gxu.edu.cn/images/icon-teacher.jpg` | 教师信息页默认头像 | `src/features/teachersInfo/components/TeacherCard.tsx:9` |

---

## 🔗 系统间依赖关系图

```
┌─────────────────────────────────────────────────────────┐
│                     用户 App                              │
└──────────┬──────────┬──────────┬──────────┬─────────────┘
           │          │          │          │
     ┌─────▼──┐ ┌────▼───┐ ┌───▼───┐ ┌───▼──────┐ ┌─────▼──────┐
     │ 教务   │ │ 统一   │ │ 考勤  │ │ 自建后端 │ │ OTA 更新  │
     │ jwxt   │ │ 认证   │ │ ykt   │ │ tool     │ │ file.unde │
     └───┬────┘ │ CA     │ └───┬───┘ └───┬──────┘ └─────┬──────┘
         │      └───┬────┘     │         │              │
         │          │          │         │              │
         ▼          ▼          ▼         ▼              ▼
    ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────────┐
    │ 课表   │ │ 教师   │ │ 物理   │ │ 工程   │ │ 问卷/文件  │
    │ 成绩   │ │ 信息   │ │ 实验   │ │ 训练   │ │ OA/ACM     │
    │ 选课   │ │ prof   │ │ PEC    │ │ xlzxms │ │ wjxt/oa    │
    └────────┘ └────────┘ └────────┘ └────────┘ └────────────┘
```

**认证流程**：
1. 统一认证系统 (CA) 是核心 SSO 入口
2. 教务系统通过 CA 获取 Cookie（JSESSIONID）
3. 考勤系统使用独立的 Token 认证
4. OA 系统使用独立的 Bearer Token
5. 自建后端直接代理教务登录，共享 Cookie

---

## 📁 文件索引

| 文件路径                                            | 负责的 API 系统              |
|-------------------------------------------------|-------------------------|
| `src/core/http.ts`                              | 教务系统 (jwxt) 核心 HTTP 客户端 |
| `src/core/auth/Jw/JwAuthClient.ts`              | 教务登录认证                  |
| `src/core/auth/attendance/attendanceAuthApi.ts` | 考勤登录认证                  |
| `src/js/auth/auth.ts`                           | 统一认证 CA + 工程训练中心        |
| `src/js/auth/attendanceSystem.ts`               | 考勤系统数据查询                |
| `src/js/jw/course.ts`                           | 课表 + 物理实验 + 工程训练        |
| `src/js/wjxt/api.ts`                            | 问卷系统                    |
| `src/js/be.ts`                                  | ACM 竞赛系统                |
| `src/features/teachersInfo/api/index.ts`        | 教师信息查询                  |
| `src/features/backend/api/index.ts`             | 自建后端基础客户端               |
| `src/features/backend/api/feedback.ts`          | 反馈 API                  |
| `src/features/backend/api/profile.ts`           | 教务配置 API                |
| `src/features/documents/api/index.ts`           | OA 文件系统                 |
| `src/features/attendance/api/index.ts`          | 考勤系统（新版）                |
| `src/features/examScore/api/index.ts`           | 考试成绩（远程 + 本地）           |
| `src/features/courseSchedule/repo/startDay.ts`  | 学期开始日                   |
| `src/features/feedback/api/event.ts`            | 事件埋点                    |
| `src/core/ota.ts`                               | OTA 热更新                 |

---

*本文档由 Claude Code 自动生成，基于项目源码 `src/` 目录下的所有网络请求调用分析。*
