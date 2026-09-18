# 教务系统 (jwxt) — 详细接口文档

## 基础信息

| 项目 | 内容 |
|------|------|
| **baseURL** | `https://jwxt2018.gxu.edu.cn/jwglxt` |
| **Content-Type** | `application/x-www-form-urlencoded; charset=UTF-8` |
| **认证方式** | Cookie (JSESSIONID) — 通过统一认证 CA 获取 |
| **withCredentials** | `true` |
| **maxRedirects** | `0` |
| **核心文件** | `src/core/http.ts` |

## 1. 登录认证

### 1.1 获取 RSA 公钥

- **方法**: `GET`
- **路径**: `/xtgl/login_getPublicKey.html?time={timestamp}`
- **文件**: `src/core/auth/Jw/JwAuthClient.ts:103`
- **返回**: `{ modulus: string, exponent: string }`
- **用途**: 获取 RSA 公钥用于密码加密登录

### 1.2 普通登录

- **方法**: `POST`
- **路径**: `/xtgl/login_slogin.html?time={timestamp}`
- **文件**: `src/core/auth/Jw/JwAuthClient.ts:107`
- **Body** (URL-encoded):
  ```json
  {
    "language": "zh_CN",
    "yhm": "{用户名}",
    "mm": "{明文密码}",
    "yzm": ""
  }
  ```
- **用途**: 明文密码登录（备用方案）

### 1.3 RSA 加密登录

- **方法**: `POST`
- **路径**: `/xtgl/login_slogin.html?time={timestamp}`
- **文件**: `src/core/auth/Jw/JwAuthClient.ts:125`
- **Body** (URL-encoded):
  ```json
  {
    "language": "zh_CN",
    "yhm": "{用户名}",
    "mm": "{RSA加密后的密码}",
    "yzm": ""
  }
  ```
- **用途**: 先用公钥加密密码，再提交登录（首选方案）

### 1.4 检测登录状态

- **方法**: `POST`
- **路径**: `/kbcx/xskbcx_cxXsgrkb.html`
- **文件**: `src/core/auth/Jw/JwAuthClient.ts:138`
- **Body**:
  ```json
  { "xnm": "2021", "xqm": "{学期代码}" }
  ```
- **判断**: 返回 `typeof data === "object"` 即为已登录

## 2. 课表查询

### 2.1 个人课表

- **方法**: `POST`
- **路径**: `/kbcx/xskbcx_cxXsgrkb.html`
- **文件**: `src/js/jw/course.ts:218`
- **Body** (URL-encoded):
  ```json
  {
    "xnm": "{学年，如2024}",
    "xqm": "{学期，如3}"
  }
  ```
- **返回**: `{ kbList: Course[], sjkList: PracticalCourse[] }`

### 2.2 班级课表列表

- **方法**: `POST`
- **路径**: `/kbdy/bjkbdy_cxBjkbdyTjkbList.html`
- **文件**: `src/js/jw/course.ts:256`
- **Body** (URL-encoded):
  ```json
  {
    "xnm": "{学年}",
    "xqm": "{学期}",
    "njdm_id": "{年级}",
    "jg_id": "{学院ID}",
    "zyh_id": "{专业ID}",
    "bh_id": "{班级ID}",
    "queryModel": { "showCount": 1000 }
  }
  ```

### 2.3 班级课表内容

- **方法**: `POST`
- **路径**: `/kbdy/bjkbdy_cxBjKb.html`
- **文件**: `src/js/jw/course.ts:287`
- **Body** (URL-encoded):
  ```json
  {
    "xnm": "{学年}",
    "xqm": "{学期}",
    "njdm_id": "{年级}",
    "jg_id": "{学院ID}",
    "zyh_id": "{专业ID}",
    "bh_id": "{班级ID}",
    "tjkbzdm": 1,
    "tjkbzxsdm": 0
  }
  ```

### 2.4 班级课表内容（新版，按班级ID）

- **方法**: `POST`
- **路径**: `/kbdy/bjkbdy_cxBjKb.html`
- **文件**: `src/js/jw/course.ts:297`
- **Body** (URL-encoded):
  ```json
  {
    "xnm": "{学年}",
    "xqm": "{学期}",
    "bh_id": "{班级ID}"
  }
  ```

## 3. 成绩查询

### 3.1 考试成绩（本地直连）

- **方法**: `POST`
- **路径**: `/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005`
- **文件**: `src/features/examScore/api/index.ts:60`
- **Body** (URL-encoded):
  ```json
  {
    "xnm": "{学年}",
    "xqm": "{学期}",
    "queryModel": {
      "showCount": "{每页条数}",
      "currentPage": "{当前页}",
      "sortName": "cjbdsj",
      "sortOrder": "desc"
    }
  }
  ```

## 4. 选课

### 4.1 获取选课列表

- **方法**: `POST`
- **路径**: `/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html`
- **文件**: `src/js/jw/course.ts:359`
- **Body** (URL-encoded):
  ```json
  {
    "xkxnm": "{选课学年}",
    "xkxqm": "{选课学期}",
    "kklxdm": "{课程类型代码}",
    "kspage": "{起始页}",
    "jspage": "{每页条数}",
    "xkkz_id": "47F02D572DC2768EE063020410AC6B75",
    "filter_list": ["{关键词}"]
  }
  ```

## 5. 个人信息

### 5.1 获取个人信息

- **方法**: `POST`
- **路径**: `/xsxxxggl/xsgrxxwh_cxXsgrxx.html?gnmkdm=N100801`
- **文件**: `src/core/auth/Jw/JwAuthClient.ts:145`
- **返回**: HTML 页面，通过 `personalInfoParser` 解析出：
  - 姓名、学院名称、年级、班级名称、专业名称、专业代码

## 6. 页面导出（WebView 跳转）

| 用途 | URL |
|------|-----|
| 个人课表导出 | `https://jwxt2018.gxu.edu.cn/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html?gnmkdm=N2151&layout=default` |
| 班级课表导出 | `https://jwxt2018.gxu.edu.cn/jwglxt/kbdy/bjkbdy_cxBjkbdyIndex.html?gnmkdm=N214505&layout=default` |

## 调用流程图

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│ 获取公钥  │────▶│ RSA登录   │────▶│ 检测登录  │
│ getPubKey │     │ slogin   │     │ testToken │
└──────────┘     └──────────┘     └─────┬────┘
                                        │
                               ┌────────▼────────┐
                               │   已登录成功      │
                               │  Cookie 已就绪    │
                               └────────┬────────┘
                                        │
            ┌───────────────────────────┼───────────────────────────┐
            │                           │                           │
      ┌─────▼──────┐           ┌────────▼──────┐          ┌───────▼───────┐
      │  个人课表    │           │   考试成绩     │          │   个人信息     │
      │  xskbcx     │           │   cjcx_cx     │          │   xsgrxxwh    │
      └────────────┘           └───────────────┘          └───────────────┘
```