# 考勤系统 (Attendance) — 详细接口文档

## 基础信息

| 项目 | 内容 |
|------|------|
| **baseURL** | `https://yktuipweb.gxu.edu.cn` |
| **认证方式** | Token（`Authorization: Token {token}`） |
| **Content-Type** | `application/json;charset=UTF-8` |
| **核心文件** | `src/js/auth/attendanceSystem.ts`（旧版，已整合） |
| **新版文件** | `src/features/attendance/api/index.ts` |
| **登录文件** | `src/core/auth/attendance/attendanceAuthApi.ts` |

## 接口列表

### 1. 登录认证

#### 1.1 获取验证码

- **方法**: `GET`
- **URL**: `https://yktuipweb.gxu.edu.cn/api/account/getVerify?num=666`
- **文件**: `src/core/auth/attendance/attendanceAuthApi.ts:12`
- **返回**: `ArrayBuffer` → 转为 base64 图片
- **用途**: 登录时需要输入验证码

#### 1.2 登录

- **方法**: `POST`
- **URL**: `https://yktuipweb.gxu.edu.cn/api/account/loginCheck`
- **文件**: `src/core/auth/attendance/attendanceAuthApi.ts:37`
- **Body**:
  ```json
  {
    "client": "web_atd",
    "loginName": "{用户名}",
    "pwd": "{AES加密后的密码}",
    "type": "1",
    "verificationCode": "{验证码}"
  }
  ```
- **密码加密**: AES/ECB/PKCS7，密钥为 `k;)*(+nmjdsf$#@d`
- **返回**: `{ code: 600, data: { token, userInfo: {...} } }`

### 2. 数据查询

#### 2.1 获取菜单/学期数据

- **方法**: `GET`
- **URL**: `https://yktuipweb.gxu.edu.cn/api/account/getIndexData?rm=SYS004`
- **文件**: `src/features/attendance/api/index.ts:42`
- **Headers**: `Authorization: Token {token}`
- **返回**: `{ code: 600, data: { calendarList: [...], ... } }`

#### 2.2 获取个人考勤记录（分页）

- **方法**: `POST`
- **URL**: `https://yktuipweb.gxu.edu.cn/api/personalData/getPersonalData?cal={termId}&rm=SYS004`
- **文件**: `src/features/attendance/api/index.ts:94`
- **Headers**: `Authorization: Token {token}`
- **Body**:
  ```json
  {
    "page_index": 1,
    "page_size": 30,
    "order_by": "",
    "search": { "ksrq": "", "jsrq": "", "courseId": "" }
  }
  ```

#### 2.3 获取考勤统计数据

- **方法**: `POST`
- **URL**: `https://yktuipweb.gxu.edu.cn/api/personalData/getPersonalDataCount?cal={termId}&rm=SYS004`
- **文件**: `src/features/attendance/api/index.ts:106`
- **Headers**: `Authorization: Token {token}`
- **Body**:
  ```json
  { "ksrq": "", "jsrq": "", "courseId": "" }
  ```

#### 2.4 获取考勤课表

- **方法**: `POST`
- **URL**: `https://yktuipweb.gxu.edu.cn/api/rank/selectByStudent?cal={termId}&rm=SYS004`
- **文件**: `src/features/attendance/api/index.ts:123`
- **Headers**: `Authorization: Token {token}`
- **Body**:
  ```json
  {
    "currentWeek": "{周数}",
    "userId": "{用户ID}"
  }
  ```

## 数据流

```
┌──────────────┐
│ 1. 获取验证码  │  GET /api/account/getVerify
└──────┬───────┘
       ▼
┌──────────────┐
│ 2. 登录      │  POST /api/account/loginCheck
│ 获取 Token   │  → 返回 token + userInfo
└──────┬───────┘
       ▼
┌──────────────────────┐
│ 3. 获取学期日历数据    │  GET /api/account/getIndexData
│ 含 calendarList      │
└──────┬───────────────┘
       │
       ├────────────────────────────────────┐
       ▼                                    ▼
┌──────────────┐                   ┌──────────────────┐
│ 4a. 考勤记录   │                   │ 4b. 考勤课表     │
│ POST personal │                   │ POST selectBy   │
│ Data          │                   │ Student          │
└──────────────┘                   └──────────────────┘
```