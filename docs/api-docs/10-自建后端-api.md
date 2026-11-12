# 自建后端 API (tool.gxutech.xyz) — 详细接口文档

本文记录 RN 时期的接口，`http://` 地址和 `src/` 路径均来自 RN 上游。iOS 版通过 HTTPS 访问同一后端，地址以 [`backendBaseURL`](../../Packages/GxuCore/Sources/GxuFoundation/Models.swift) 为准。

## 基础信息

| 项目 | 内容 |
|------|------|
| **baseURL** | `http://api.tool.gxutech.xyz` |
| **Content-Type** | `application/json` |
| **超时时间** | 10 秒 |
| **认证方式** | Cookie (JSESSIONID) — 与教务系统共享 |
| **核心文件** | `src/features/backend/api/index.ts` |

## 接口列表

### 1. 教务代理

#### 1.1 教务登录代理

- **方法**: `POST`
- **URL**: `http://api.tool.gxutech.xyz/jw/login`
- **文件**: `src/core/auth/Jw/JwAuthClient.ts:52`
- **Body**:
  ```json
  { "username": "{学号}", "password": "{密码}" }
  ```
- **返回**: `Set-Cookie` 头中包含 `JSESSIONID` 和 `route`
- **用途**: 服务端代理登录教务系统，返回 Cookie 给客户端

#### 1.2 获取教务配置

- **方法**: `POST`
- **URL**: `http://api.tool.gxutech.xyz/jw/profile`
- **文件**: `src/features/backend/api/profile.ts:4`
- **Body**:
  ```json
  { "isFull": false }
  ```

#### 1.3 获取学期开始日

- **方法**: `GET`
- **URL**: `http://api.tool.gxutech.xyz/jw/profile/startDay`
- **文件**: `src/features/courseSchedule/repo/startDay.ts:15`
- **返回示例**:
  ```json
  {
    "data": [
      { "year": 2024, "term": 1, "day": "2024-09-02", "week": 1, "is_current": false },
      { "year": 2025, "term": 1, "day": "2025-02-24", "week": 1, "is_current": true }
    ]
  }
  ```

### 2. 成绩代理

#### 2.1 获取考试成绩

- **方法**: `GET`
- **URL**: `http://api.tool.gxutech.xyz/jw/score`
- **文件**: `src/features/examScore/api/index.ts:33`
- **Params**:
  - `pageSize` — 每页条数
  - `pageNo` — 页码
  - `orderBy` — 排序字段（默认 `desc`）
  - `order` — 排序方向（默认 `cjbdsj` 考试时间）
  - `year` — 学年（可选）
  - `term` — 学期（可选）
- **用途**: 优先通过代理获取成绩，失败时回退到教务直连

#### 2.2 获取平时成绩

- **方法**: `GET`
- **URL**: `http://api.tool.gxutech.xyz/jw/score/usual`
- **文件**: `src/features/examScore/api/index.ts:86`
- **Params**:
  - `year` — 学年（可选）
  - `term` — 学期（可选）
  - `id` — 课程ID

### 3. 反馈系统

#### 3.1 提交反馈

- **方法**: `POST`
- **URL**: `http://api.tool.gxutech.xyz/feedback`
- **文件**: `src/features/backend/api/feedback.ts:12`
- **Body**:
  ```json
  {
    "userId": "{学号}",
    "deviceModel": "{设备型号}",
    "appVersion": "{应用版本}",
    "title": "{标题}",
    "content": "{内容}",
    "images": ["{图片URL}"]
  }
  ```

#### 3.2 获取反馈列表

- **方法**: `GET`
- **URL**: `http://api.tool.gxutech.xyz/feedback/{userId}`
- **文件**: `src/features/backend/api/feedback.ts:16`
- **Params**: `page`, `pageSize`

### 4. 事件埋点

#### 4.1 提交事件

- **方法**: `POST`
- **URL**: `http://api.tool.gxutech.xyz/event`
- **文件**: `src/features/feedback/api/event.ts:19`
- **Body**:
  ```json
  {
    "userId": "{学号}",
    "eventName": "{事件名}",
    "feature": "{功能模块}",
    "appVersion": "{应用版本}"
  }
  ```
- **事件列表**:
  | eventName | feature | 触发时机 |
  |-----------|---------|---------|
  | `login_jw_success` | `login` | 教务登录成功 |
  | `open_app` | `app` | 应用启动 |

## 架构说明

自建后端在整个应用中扮演 **代理/网关** 角色：

```
┌──────────┐       ┌──────────────────┐       ┌──────────┐
│  App     │──────▶│ 自建后端          │──────▶│ 教务系统  │
│ 客户端   │       │ api.tool.gxutech │       │ jwxt     │
│          │◀──────│ .xyz             │◀──────│          │
└──────────┘       └──────────────────┘       └──────────┘
                         │
                    ┌────▼────┐
                    │ 数据库   │
                    │ (反馈/   │
                    │  埋点)   │
                    └─────────┘
```

**优势**：
1. 成绩查询走代理 → 解析教务 HTML 为 JSON，减少客户端负担
2. 教务 Cookie 可通过代理中转，无需客户端直接处理复杂登录
3. 反馈和埋点数据集中存储