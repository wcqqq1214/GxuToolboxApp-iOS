# 福州大学「福uu」fzuhelper vs 西大工具箱 全栈竞品分析报告

> 目的：详尽剖析同类产品 fzuhelper（福州大学校园助手）的**全栈代码**，并实测对照我们自己的产品链，供优化现有功能、规划新功能、设计后端参考。"师夷长技以制夷"。
>
> **所有结论均基于实测代码**，证据以文件路径标注。
>
> 竞品仓库（已全部本地拉取至 `D:\coding\fzuapp\`）：客户端 `fzuhelper-app`(v7.2.6)、服务端 `fzuhelper-server`、本科教务库 `jwch`(v0.2.44)、研究生教务库 `yjsy`(v0.0.10)、魔改 `eas-cli`(对我们无用)。
>
> 我们的产品链（已全部本地实测）：客户端 `gxu_tool_app`(v2.1.3 beta)、后端 `tool-app-be`、管理端 `tool-app-admin`、教务库 `tool-adapter`、文档站 `GxuToolAppDoc`、介绍页 `gxu-tool-intro`、旧后端 `GxuToolWebBE`(已退役)。
>
> 生成日期：2026-08-01

---

## 〇、TL;DR（先看结论）

- **双方都是全栈产品链，不是"全栈 vs 轻量"**。我们也有完整的 7 仓库产品链（客户端+后端+管理端+教务库+文档站+介绍页+旧后端），只是刚起步；对方是 5 仓库（客户端+服务端+教务库+教务库+eas-cli），运营 10 年。
- **产品链完整度：我们在"管理端 + 文档站 + 介绍页"环节领先**（对方无独立管理端、用飞书文档、无落地页）；**对方在"服务端深度 + 双端 + Widget + 推送 + AI"领先**。
- **★ 认证机制关键修正**：之前以为我们 `login-proxy.md` 提案（加密 Token 内含 cookie）已落地--**实测未落地**。我们后端实际是"**后端代登录 + 明文 cookie 透传**"（`nestjs-cls` 上下文传 cookie）。所以：
  - 比竞品优：**登录在后端**（突破"晚 11 点不准登录"+ 前端不内嵌登录逻辑）。
  - 与竞品相当：**cookie 明文传输**（提案的 Token 封装未实现，安全性没达到目标）。
- **后端定位差异**：我们 `tool-app-be` 是**轻量代理网关**（NestJS 单体，4 张表，实时代理教务不缓存）；竞品 `fzuhelper-server` 是**完整业务后端**（Go 11 微服务，12+ 表，缓存/推送/配置/社交/AI 全套）。
- **教务库定位差异**：我们 `tool-adapter` 是**纯数据清洗库**（2 模块，cheerio+zod，仅后端引用）；竞品 `jwch/yjsy` 是**端到端爬虫库**（~20 方法，含登录/cookie/OCR）。
- **我们的护城河（守住）**：① OTA 热更新（对方没有）；② 后端代登录突破时段限制；③ 独立管理端+文档站；④ Zod+OP-SQLite；⑤ 零广告纯净；⑥ 教务深度。
- **最该抄**：服务端 Token 封装 cookie（补完 login-proxy 提案，安全性超越竞品）、成绩变更推送、LLM 解析通知、空教室/日历订阅、工具箱云配置、singleflight、CI/CD。

---

## 一、产品概览

| 维度 | fzuhelper（竞品） | 西大工具箱（我们） |
|---|---|---|
| 产品名 | 福uu（FzuHelper） | 西大工具箱 - 移动教务 |
| 学校 | 福州大学 | 广西大学 |
| 运营方 | 学生组织 west2-online | 广西大学 XCPC 技术组 |
| 上线 / 规模 | 2015 年，日均 2~3 万学生 | 较新（v2.1），公测群分发 |
| 全栈范围 | 客户端 + 服务端 + 教务库（全栈自研） | 客户端 + 后端 + 管理端 + 教务库 + 文档站 + 介绍页（全栈，刚起步） |
| 平台 | **Android + iOS 双端** + 桌面/控制中心 Widget | **仅 Android** + 桌面 Widget |
| License | AGPL-3.0 | 开源（自建 GitLab） |
| 商业化 | **有开屏广告 + Banner** | **零广告、无跟踪** |
| 服务端规模 | Go 11 微服务，12+ 表，23000+ 用户 | NestJS 单体，4 表，公测阶段 |

---

## 二、★ 产品链全景对比（核心）

### 2.1 我们的产品链（7 仓库实测）

| # | 仓库 | 职责 | 技术栈 | 域名/部署 |
|---|---|---|---|---|
| 1 | `gxu_tool_app` | Android 客户端 | RN 0.84 + React 19 + Zustand + React Nav 7 + MMKV/OP-SQLite + Widget | APK + OTA(`file.unde.site`) |
| 2 | `tool-app-be` | **主后端**（教务代理 + 埋点 + 反馈 + 统计 + 用户） | **NestJS 11 + Prisma 7 + PostgreSQL + Swagger** | `api.tool.gxutech.xyz` |
| 3 | `tool-app-admin` | **管理端**（数据看板 + 反馈审核 + 用户分析） | **Vue 3.5 + Vite 8 + Element Plus + ECharts** | `admin.tool.gxutech.xyz`，Docker nginx |
| 4 | `tool-adapter` | 教务数据解析库（纯清洗） | TS + cheerio + zod（私有 npm 包 `gxu-tool-adapters`） | git 分发 |
| 5 | `GxuToolAppDoc` | **文档站**（用户使用文档） | **VuePress 2** + Vue 3 | 端口 7533，GitHub Actions 自动部署 |
| 6 | `gxu-tool-intro` | 介绍页/落地页 | React 19 + Vite 6 + Tailwind v4 + shadcn/ui | 待部署（域名待填） |
| 7 | `GxuToolWebBE` | 旧版后端（**已退役**） | NestJS + TypeORM + JWT 自建账号 | `acm.gxu.edu.cn/gxuicpc`，仅遗留 `/app/record` 日志 |

**关系**：客户端消费 `tool-app-be`（+ 遗留调用 `GxuToolWebBE` 的日志接口）；管理端共用 `tool-app-be` 的 `/metrics /event /feedback /user`；`tool-app-be` 依赖 `tool-adapter` 清洗教务数据；客户端通过 gateway `remote_first`（后端优先 + 本地兜底）切换。

### 2.2 对方的产品链（5 仓库实测）

| # | 仓库 | 职责 | 技术栈 | 域名 |
|---|---|---|---|---|
| 1 | `fzuhelper-app` | 客户端 | Expo SDK 56 + RN 0.85 + React 19 + NativeWind + React Query | - |
| 2 | `fzuhelper-server` | **服务端**（完整微服务全栈） | **Go 1.26 + Hertz + Kitex + etcd + gorm + MySQL + Redis** | `fzuhelper.west2.online` |
| 3 | `jwch` | 本科教务对接库（端到端） | Go + resty + antchfx/htmlquery | - |
| 4 | `yjsy` | 研究生教务对接库（端到端） | Go + resty + htmlquery | - |
| 5 | `eas-cli` | 魔改 EAS CLI（fork，`--local` 本地 fastlane 提交） | TS | 对我们无用 |

**关系**：客户端登录教务（调 jwch 库）拿 cookie -> 向 `fzuhelper-server` 换 JWT -> 后续带 JWT+cookie 三件套请求；服务端用 jwch/yjsy 库代理教务业务；无独立管理端、文档用飞书、无落地页。

### 2.3 完整度对比

| 环节 | 我们 | 对方 | 胜出 |
|---|---|---|---|
| 客户端 | RN（仅 Android） | Expo（Android+iOS+Widget+控制中心） | **对方**（双端+多形态 Widget） |
| 服务端 | NestJS 单体，4 表，轻量代理 | Go 11 微服务，12+ 表，完整业务 | **对方**（深度+规模） |
| 教务库 | 纯清洗库（2 模块） | 端到端库（~20 方法） | **对方**（能力面），我们抽象更现代 |
| **管理端** | **Vue 看板（DAU/留存/反馈审核/用户画像）** | **无** | **我们** |
| **文档站** | **VuePress 自建（教程/FAQ/版本日志，CI 部署）** | 飞书文档 | **我们** |
| **介绍页** | **React 落地页**（待部署） | 无 | **我们** |
| OTA 热更新 | **JS bundle 级** | **无** | **我们** |

**结论**：我们在**运营侧（管理端+文档站+介绍页）**和**OTA**领先；对方在**技术深度侧（服务端+双端+Widget+推送+AI）**领先。双方各有护城河。

---

## 三、客户端技术栈与架构对比

| 维度 | fzuhelper-app | gxu_tool_app |
|---|---|---|
| 框架 | Expo SDK 56（prebuild） | Bare RN CLI |
| RN/React | 0.85.3 / 19.2.3 | 0.84 / 19.2.3 |
| 路由 | Expo Router（文件式 + typedRoutes） | React Navigation 7（命令式 lazy） |
| UI | NativeWind v4 + shadcn（@rn-primitives） | @rneui/themed + 自研 un-ui（19 组件） |
| 服务端状态 | **TanStack React Query v5**（选择性持久化） | **无**（直接 axios + 手动缓存） |
| 客户端状态 | Context + zustand（隐式依赖） | Zustand 5 |
| 网络 | axios + 自研原生 HTTP 模块 | axios 多实例 |
| 数据校验 | 靠生成类型 | **Zod 4** |
| 持久化 | 仅 AsyncStorage | **OP-SQLite + MMKV + AsyncStorage** |
| 推送 | 友盟多厂商 | 无 |
| 崩溃上报 | Bugly | 无 |
| Widget | iOS WidgetKit + Android AppWidget + iOS ControlWidget（原生） | react-native-android-widget（JS） |

**客户端工程亮点（对方）**：① OpenAPI 全链路代码生成（Apifox -> openapi-ts -> `api/generate/` + `backend.d.ts` 类型派生）；② 双层 forbidden-imports（ESLint + Babel 编译期阻断，强制统一组件/主题）；③ 完整 CI/CD（GitHub Actions：构建->alpha/beta->自动 bump version PR）；④ axios 请求队列 + 自动重登（`refreshing`+`PendingTask[]`，业务无感）；⑤ 版本号 = 版本名 + commit 次数（单调递增）。

**客户端工程亮点（我们）**：① Zod 运行时校验；② OP-SQLite 结构化存储 + repository 模式；③ `createAuthCore` 统一认证状态机（三套系统抽象，比对方 jwch/yjsy 复制演化优雅）；④ 自研 OTA；⑤ `best_practice.md` 内省文档（P0-P5 偿债计划）。

**客户端共同短板**：双方都零测试文件。我们额外：tsc 不通过、无 CI、http interceptor bug（`return error` 而非 `reject`）。

---

## 四、服务端架构与技术栈对比（实测）

### 4.1 对方 fzuhelper-server（Go 微服务全栈）

- **技术栈**：Go 1.26 + CloudWeGo **Hertz**(Web) + **Kitex**(RPC) + **etcd**(服务发现) + **viper**(配置热更新) + **gorm** + **MySQL 9** + **Redis** + **又拍云** + **阿里 Sentinel**(限流) + **OpenTelemetry**(Tempo/Loki/Prometheus) + golang-jwt(Ed25519) + go-openai/mcp-go(AI)。
- **分层**：Hertz 网关(api/) -> Kitex RPC(etcd 发现) -> 11 微服务(handler/service/pack) -> pkg/db。请求流：HTTP -> 网关(鉴权/限流) -> RPC -> 微服务 -> jwch/yjsy/DB/Redis。
- **数据库 12+ 表**：student、scores(JSON+SHA256 变更检测)、course(JSON+SHA256)、course_offerings(course_hash 推送去重)、follow_relation(**GENERATED VIRTUAL 列**解决软删除唯一约束)、launch_screen(学号正则定向投放)、toolbox_config(多维匹配)、notice、auto_adjust_course(LLM 提取+人工审核)、visit、feedback、course_teacher_scores。
- **API**：v1(login/academic/course/classroom/user/friend/launch-screen/toolbox/feedback/common)、v2(version/apk/云配置)、**MCP**(`/mcp` 10 工具供 AI Agent)、兼容路由。
- **鉴权**：Ed25519 JWT（私钥配置/**公钥硬编码源码**），Access 7天/Refresh 30天，**每次鉴权滑动续签**；JWT Claims 仅 student_id+type（实际传空 stuID，**不绑定用户身份**）；教务 cookie 客户端明文头传，网关 `GetHeaderParams` 透传。
- **部署**：多阶段 Docker + **K8s Helm Chart**（1 副本，ConfigMap 热更新）+ CI/CD（ci.yaml 5 并行 job + deploy.yaml 手动 matrix + codeql + vulncheck + dependabot）。
- **工程实践**：4 段式错误码体系(10000/200xx/300xx/400xx/500xx，含 stack)、统一响应、Thrift IDL 代码生成(hz+kitex)、**singleflight 防击穿**、**TaskQueue 异步化**、滑动窗口监控告警、License 检查。

### 4.2 我们 tool-app-be（NestJS 轻量代理，实测）

- **技术栈**：**NestJS 11** + **Prisma 7** + **PostgreSQL** + **Swagger(/docs)** + @nestjs/axios + cheerio + class-validator + **nestjs-cls**（请求上下文传 cookie/UA）+ crypto-js + gxu-tool-adapters。pnpm。
- **分层**：NestJS 模块化（单服务）。模块：`jw-system/`(login/profile/score/schedule + jw-http.service)、`event/`(埋点)、`feedback/`(反馈)、`metrics/`(统计看板)、`user/`(用户管理)、`attendance/`(考勤，有代码未文档化)、`evaluation/`(评教，有代码未文档化)、`common/`(拦截器/过滤器/DTO)、`prisma/`。
- **数据库仅 4 表**（`prisma/schema.prisma`）：`Event`(埋点)、`Major`(专业代号)、`Feedback`(反馈)、`TermStartDay`(学期起始日)。**不存课表/成绩/用户信息**（实时代理教务，不缓存）。
- **API**（README 路由总表）：`/jw/*`(login/profile/score/schedule，需 cookie)、`/event`、`/feedback`、`/metrics`(DAU/WAU/MAU/版本分布/趋势)、`/user`(列表/画像/留存)。`/event /feedback /metrics /user` **无需鉴权**。
- **鉴权（实测，关键）**：`POST /jw/login` 后端代登录教务（**RSA 优先**：getPublicKey 拿公钥+初始cookie -> `getEncryptedPassword` 加密密码 -> POST `/xtgl/login_slogin.html` -> 302 成功，解析 set-cookie 得 JSESSIONID+route，`mergeCookies` 返回 `{cookie}`；**失败回退明文** loginNormal）。后续 `/jw/*` 前端带 cookie，后端 **nestjs-cls** 从入站头读 cookie+UA，在 `JwHttpService` axios 拦截器自动透传给教务。遇 302 抛 401"登录态过期"。
- **工程实践**：全局 `ValidationPipe`(whitelist+forbidNonWhitelisted+transform)、`TransformInterceptor` 统一响应 `{code:200,message,data}`（code 是 HTTP 码）、`HttpExceptionFilter` 异常处理、日志隐藏 password、Prisma migrate 迁移、Swagger /docs 在线调试、jest spec 文件。
- **部署**：Dockerfile + docker-compose（dev/生产）。**未显式启用 CORS**。

### 4.3 服务端对比

| 维度 | fzuhelper-server | tool-app-be |
|---|---|---|
| 语言/框架 | Go / Hertz+Kitex 微服务 | TS / NestJS 单体 |
| 规模 | 11 微服务，12+ 表，23000+ 用户 | 单服务，4 表，公测 |
| 定位 | 完整业务后端（缓存/推送/配置/社交/AI） | **轻量代理网关**（实时代理，不缓存） |
| 登录 | 客户端登录，后端只验 session | **后端代登录**（RSA+回退明文） |
| cookie | 客户端明文头传 | 客户端明文头传（nestjs-cls 透传） |
| 缓存 | Redis + DB(JSON+SHA256) | 无（实时代理） |
| 推送 | 友盟多厂商 + 成绩变更精准推送 | 无 |
| AI | LLM 调课解析 + MCP Server | 无 |
| 在线文档 | 无 | **Swagger /docs** |
| 代码生成 | Thrift IDL(hz+kitex) | 无 |
| 防击穿 | singleflight | 无 |
| 部署 | K8s Helm + CI/CD | Docker compose |
| 鉴权缺口 | 管理端接口无鉴权 | `/metrics /feedback /user` 无鉴权 |

**解读**：对方是"大而全"完整后端，我们是"小而精"代理网关。**我们不需要照搬对方规模**，但应补：Token 封装 cookie（补完 login-proxy）、推送、缓存（成绩变更检测）、CI/CD。我们的 Swagger 在线文档是对方没有的优势。

---

## 五、教务对接库对比（实测）

### 5.1 对方 jwch / yjsy（端到端 Go 库）

- **定位**：端到端教务爬虫库，被 server 引用。jwch(本科,v0.2.44 成熟) + yjsy(研究生,v0.0.10，fork 自 jwch)。
- **技术栈**：Go 1.23 + resty + **antchfx/htmlquery(XPath)** + x/text(GB2312)。
- **登录**：jwch 清cookie -> MD5-16 密码 -> 取验证码 -> **服务端 OCR**(`statistics.fzuhelper.w2fzu.com` 微服务，纯算法余弦相似度) -> logincheck.asp -> 从 `err.Error()` 正则抠 token/id -> SSOLogin -> 换 cookie + identifier -> **串号校验**（页面上学号==输入学号）。yjsy：Base64 密码，无验证码无 SSO，无串号校验。
- **能力 ~20 方法**：课表(含**调课合并算法 ApplyAdjustRules**，14 个单测)、成绩/统考、培养计划、空教室(按楼并发)、考场、通知、讲座、学分/绩点、校历(GB2312)、个人信息。
- **防封**：**青果隧道代理 IP 轮换**（QINGGUO 环境变量）。
- **短板**：两库**无公共抽象**复制演化；从 `err.Error()` 正则抠 URL（依赖 resty 格式）；字符串包含判过期；`InsecureSkipVerify`；yjsy 绝对路径 XPath 脆；无 context/超时。

### 5.2 我们 tool-adapter（纯清洗 TS 库，实测）

- **定位**：**纯数据清洗库**（不发任何 HTTP、无登录/cookie/加密），只接收"已抓到的原始数据"输出结构化对象。包名 `gxu-tool-adapters`，**仅 `tool-app-be` 后端引用**（客户端不引用，自带本地解析兜底）。git 分发，`private:true`，无语义版本。
- **技术栈**：TS 5.9（**strict + noUncheckedIndexedAccess + exactOptionalPropertyTypes**，极严苛）+ **cheerio**(CSS 选择器) + **zod**(schema 校验) + vitest。
- **能力仅 5 函数**：`parseScore`/`parseUsualScore`（成绩）、`parseSchedule`/`parseClass`/`parseMajor`（课表）。只覆盖**正方本科教务的课表+成绩**两模块。
- **亮点**：zod `safeParse` 容错 + `.transform()` 字段映射 + `optional().default()` 容缺（对脏数据鲁棒）；`OriginalScore`/`OriginalCourse` 详尽字段字典（60+ 字段中文 JSDoc）；`parseWeeks` 单双周处理；vitest 测试扎实；运行时仅 cheerio+zod 极简。
- **短板**：覆盖面窄（只 2 模块，无考试/评教/选课/登录）；与客户端 `src/js/usualScoreParser.ts` **同源分叉**（两份代码）；非真正独立包；`safeParse` 失败静默返回空数组（排障难）；无系统级抽象。

### 5.3 教务库对比

| 维度 | jwch/yjsy | tool-adapter |
|---|---|---|
| 定位 | 端到端爬虫库 | **纯清洗库** |
| 能力 | ~20 方法（含登录/OCR/代理） | 5 函数（课表+成绩） |
| 解析 | antchfx/htmlquery **XPath** | cheerio **CSS 选择器** + **zod 校验** |
| 登录/cookie | 库内全包 | **库内无**（在客户端+后端） |
| 防封 | 青果代理 IP 轮换 | 无（靠后端 24h 校园网） |
| 多系统 | 两库复制演化（教训） | 单库，无系统抽象 |
| 独立性 | 高（可被任意 Go 项目用） | 低（私有 git，仅内部后端） |

**解读**：对方"端到端做库"，我们"只把后端清洗做库"。我们能力面窄但抽象更现代（zod+类型字典），对方端到端但复制演化。**我们的教训**：客户端 `usualScoreParser` 与 adapter 已分叉，应统一；**启示**：若扩系统，先定义统一 interface 再实现（避免重蹈 jwch/yjsy 复制覆辙，我们 `createAuthCore` 已走在前面）。

---

## 六、★ 认证与登录机制（关键修正）

### 6.1 三方对比（提案 / 对方 / 我们实测）

| 维度 | 我们 login-proxy.md **提案** | fzuhelper **实测** | 我们 tool-app-be **实测** |
|---|---|---|---|
| 登录位置 | 后端全代理 | **客户端**自行登录 | **后端代登录**（RSA+回退明文） |
| 返回物 | 加密签名 Token（内含 cookies/createdAt/expiresAt/studentId） | JWT（仅 student_id+type）+ 客户端持有 cookie | **明文 cookie 字符串**（JSESSIONID+route） |
| 后续请求 | 只带 Token | JWT + Id + Cookies 三件套（明文） | cookie（明文，nestjs-cls 透传） |
| 后端存密码 | 不存 | 不存 | 不存 |
| cookie 安全 | **加密在 Token 内** | 明文 HTTP 头 | **明文**（提案未落地） |
| 突破时段限制 | 能（后端 24h 校园网） | **不能**（客户端受用户网络限制） | **能**（后端 24h 校园网） |
| 前端复杂度 | 低（只提交账密） | 高（内嵌登录+爬虫） | **低**（只提交账密） |

### 6.2 关键结论

1. **login-proxy 提案未完全落地**：后端代登录 ✅ 已实现（`login.service.ts`），但"Token 封装 cookie" ❌ 未实现--实际返回明文 cookie 字符串。安全性实际与竞品相当（都明文 cookie），**没达到提案目标**。
2. **我们仍优于竞品的两点**：① 登录在后端（突破"晚 11 点不准登录"+ 前端不内嵌登录逻辑）；② 前端简化（只提交账密，不跑完整爬虫登录）。
3. **P0 行动**：补完 login-proxy 提案--后端代登录后将 cookie 封装成加密签名 Token 返回，前端只存 Token，后续请求带 Token，后端解封取 cookie 代理教务。这样**安全性超越竞品**（cookie 不明文流转），兑现提案价值。

### 6.3 验证码 OCR

对方：jwch 登录调 `statistics.fzuhelper.w2fzu.com` 纯算法 OCR 微服务（余弦相似度+模板，零 ML 部署成本）。我们：考勤系统验证码用户手输，无 OCR。**可借鉴**：纯算法 OCR 或接通用 OCR 服务放后端。

---

## 七、推送与 AI 能力（对方有，我们没有）

- **多厂商推送**：友盟 U-Push groupcast + 小米/华为/vivo/oppo/荣耀通道。异步限流 Dispatcher（非阻塞入队+串行消费+1 分钟间隔+每日 500 配额）。
- **★ 成绩变更精准推送**：Redis 缓存 -> `jwch.GetMarks` -> **SHA256 比对** DB `scores_info_sha256` -> 变更课程算 `courseHash` -> 查 `course_offerings` 防重 -> MD5 tag groupcast -> 写 `course_offerings`。客户端订阅课程时注册 MD5 tag，后端按 tag 精准推送。
- **★ LLM 自动解析调课通知**：监控通知含"课程调整" -> `GetNoticeDetail` 取 HTML -> **LLM 提取结构化调课条目** -> 校历映射周次 -> 写 `auto_adjust_course`(**Enabled=false 人工审核**) -> 刷缓存。**AI 嵌入业务流程，非 chatbot，最亮眼**。
- **MCP Server**：`/mcp` 暴露 10 个教务工具供 AI Agent 调用。

**对我们**：成绩变更推送 + LLM 解析通知（我们已有调课/调休/节假日通知模块，可升级为自动解析）是高价值可借鉴方向。

---

## 八、功能全景（客户端）

**对方功能**（广度领先）：课表(日历订阅/自定义/好友课表)、成绩/绩点/学分/统考/培养计划、考场(导入课表)、教务通知、校历、选课、各类申请、学生证补办、毕业设计、一键评议、**历年卷库**、验证码 OCR、**一码通**、**学习中心座位预约+扫码签到**、**空教室查询**(7校区)、水电缴费、公寓报修、电动车登记、**好友/约好友**(空闲时间匹配)、招聘会、飞跃手册、校园指南 Wiki、20+ SSO WebView、多厂商推送、主题换肤+壁纸、**多形态桌面 Widget + iOS 控制中心 Widget**、开屏广告+Banner、**工具箱云配置**、开发者工具隐藏页。

**我们功能**（深度领先）：课表(冲突检测/周视图/班级课表/全校实时课表/导出WakeUp)、考试考场、考试成绩(远程代理+本地兜底)、**GPA 计算器**、考勤信息(课表同屏)、选课列表、**校选课查漏**、**教师信息查询**、物理实验课、金工实训、调课/调休/节假日通知、**OA 文件系统**、**自动评教**(模板录制+批量提交，存 SQLite)、地图导航、教学楼平面图、Widget 预览、OTA、版本管理。

**对方有我们没有**（推新作候选）：空教室查询、课表日历订阅、验证码 OCR、多厂商推送、工具箱云配置、考场导入课表、历年卷库、学习中心座位预约、好友/约好友、招聘会、一码通、iOS 端+Widget、崩溃上报、开发者工具页。

**我们有对方没有**（差异化）：OTA 热更新、后端代登录、班级课表/全校实时课表、校选课查漏、教师信息、教学楼平面图、OA 文件、自动评教工程化、考勤同屏、GPA 计算器、课表导出 WakeUp、零广告纯净。

---

## 九、多端与系统级能力

| 能力 | fzuhelper | 我们 |
|---|---|---|
| Android / iOS | ✅ / ✅ | ✅ / ❌ |
| iOS 桌面 Widget / 控制中心 | ✅ / ✅ | ❌ / ❌ |
| Android Widget | ✅ 原生 | ✅ JS |
| **OTA 热更新** | ❌ | ✅ **自研 JS bundle 级** |
| 推送 / 崩溃上报 | ✅ / ✅ Bugly | ❌ / ❌ |
| 日历订阅 / DeepLink | ✅ / ✅ | ❌ / ❓ |

---

## 十、外部仓库与域名

**对方**（`D:\coding\fzuapp\`）：fzuhelper-app / fzuhelper-server / jwch / yjsy / eas-cli。域名：`fzuhelper.west2.online`(API)、`statistics.fzuhelper.w2fzu.com`(OCR)、`download.w2fzu.com`(CDN)、`files.w2fzu.com`(文件)、`fzuwiki.west2.online`(Wiki)、`run.west2.online`(飞跃手册)。

**我们**：gxu_tool_app / tool-app-be / tool-app-admin / tool-adapter / GxuToolAppDoc / gxu-tool-intro / GxuToolWebBE(退役)。域名：`api.tool.gxutech.xyz`(后端)、`admin.tool.gxutech.xyz`(管理端)、`tooldoc.gxutech.xyz`(文档站)、`file.unde.site`(OTA)、`gitlab.unde.site/gxutool/*`(代码)、`acm.gxu.edu.cn/gxuicpc`(旧后端遗留)。集成 12 个校内系统（教务/统一认证/考勤/教师/OA/问卷/物理实验/工程训练等）。

---

## 十一、全栈对比总结

| 维度 | 我们领先 | 对方领先 |
|---|---|---|
| 产品链完整度 | 管理端 + 文档站 + 介绍页 | - |
| 客户端 | OTA、Zod、OP-SQLite、教务深度 | 双端、Widget、React Query、OpenAPI 代码生成、编译期约束、CI/CD |
| 服务端 | 后端代登录、Swagger 文档 | 微服务全栈、缓存、推送、AI、singleflight、K8s、错误码体系 |
| 教务库 | zod 校验、类型字典、抽象现代 | 端到端能力面、OCR、代理防封 |
| 认证 | 登录在后端（突破时段限制） | -（双方都明文 cookie，我们提案未落地） |
| 运营 | 零广告纯净、管理看板 | 推送精准触达 |

---

## 十二、师夷长技：可落地建议（按优先级）

### P0：补完核心安全 + 修 bug
1. **★ 补完 login-proxy 提案**：后端代登录后将 cookie 封装成加密签名 Token（含 cookies/createdAt/expiresAt/studentId）返回，前端只存 Token，后续带 Token。**安全性超越竞品**（cookie 不明文流转）。这是兑现我们自己提案，最高优先级。
2. **修 http interceptor bug**（`src/core/http.ts:36`、`backend/api/index.ts:18` `return error` -> `Promise.reject`）。
3. **加 token 刷新请求队列**（学对方 `refreshing`+`PendingTask[]`，业务无感）。
4. **★ 管理端 + 后端管理接口加鉴权**：`tool-app-admin` 无登录/路由守卫，`/metrics /feedback /user` 无鉴权（与竞品管理端无鉴权一样的隐患）。补 JWT + 路由守卫。这是 P0 安全风险。
5. **统一认证路径** + **加串号校验**（学 jwch 登录后比对学号）。

### P1：工程实践
6. **代码生成**：客户端 OpenAPI（学对方 openapi-ts + 类型派生）；服务端可考虑 NestJS Swagger 自动生成客户端类型。
7. **CI/CD**：抄对方 GitHub Actions（lint+tsc+test+构建），我们无 CI。
8. **双层 forbidden-imports**：强制 un-ui 统一组件，编译期阻断。
9. **补测试 + 修 tsc**：双方都零测试，优先纯转换函数。
10. **服务端工程化借鉴**：错误码体系、统一响应（已有）、singleflight 防击穿、TaskQueue 异步化、Prisma 迁移（已有）。

### P2：服务端能力升级
11. **成绩缓存 + 变更检测**：学对方 JSON+SHA256，为推送打基础（我们后端现在实时代理不缓存）。
12. **TanStack React Query**（客户端）：简化数据层。

### P3：推新功能（高价值低成本优先）
13. **课表日历订阅**（.ics，低成本高价值，后端可生成 token）。
14. **空教室查询**（我们有全校实时课表数据基础）。
15. **工具箱云配置**（后端下发，多维匹配；`best_practice.md` P3 已要求抽配置）。
16. **验证码 OCR**（后端纯算法或接 OCR，解决考勤验证码痛点）。
17. **崩溃上报**（Bugly/Sentry）。
18. **开发者工具隐藏页**。

### P4：中长期
19. **多厂商推送**（成绩/考试/调课变更推送，学对方 SHA256 变更+MD5 tag 精准推送）。
20. **★ LLM 解析通知**（学对方 AI 嵌入业务流程，把调课/调休/节假日通知升级为自动解析+人工审核）。
21. **正式下线 GxuToolWebBE**（迁移 `/app/record` 到 tool-app-be）。
22. **完成 gxu-tool-intro 落地页部署**。
23. **好友/约好友**、历年卷库、考场导入课表。

### 借鉴的小技巧
- 版本号 = 版本名 + commit 次数；tag 触发自动 bump PR。
- MySQL GENERATED VIRTUAL 列解决软删除唯一约束；JSON+SHA256 变更检测。
- singleflight 防击穿；TaskQueue 非关键路径异步化；滑动窗口 JWT 续签。
- 签名密钥从 secrets 注入（我们 build.gradle 硬编码密码 `gxutoolapp` 是隐患）。
- 教务库统一 interface（吸取 jwch/yjsy 复制演化教训）。
- tool-adapter 与客户端 `usualScoreParser` 分叉，应统一去重。

---

## 十三、对方短板 / 我们差异化优势

### 对方短板
1. **无 OTA 热更新**（最大短板，每次发整包）。
2. **登录在客户端 + cookie 明文传输**（安全性弱；我们后端代登录更优，补完 Token 封装后超越）。
3. **管理端接口无鉴权**（开屏 CRUD/工具箱配置/反馈列表任何人可调）。
4. JWT 不绑定用户身份（token 借用风险）；公钥硬编码源码。
5. 客户端承担登录复杂度（前端臃肿）。
6. 测试缺失；单副本部署；Kafka 声明未用；可观测组件注释未落地。
7. 教务库从 `err.Error()` 正则抠 URL、`InsecureSkipVerify`、jwch/yjsy 无公共抽象。
8. 有开屏广告（商业化）；zustand 隐式依赖。

### 我们差异化优势（守住并放大）
1. **OTA 热更新**（碾压级，对方没有）。
2. **后端代登录突破时段限制**（补完 Token 封装后安全性也超越）。
3. **独立管理端 + 文档站 + 介绍页**（产品链运营侧完整，对方没有）。
4. **零广告纯净**。
5. **Zod + OP-SQLite**（运行时校验 + 结构化存储，对方仅 AsyncStorage）。
6. **`createAuthCore` 统一认证状态机**（比 jwch/yjsy 复制演化优雅）。
7. **自动评教工程化**（模板录制+批量提交）。
8. **教务深度**（班级课表/全校课表/校选课查漏/教师信息/教学楼平面图/考勤同屏/GPA 计算器/课表导出）。
9. **Swagger 在线 API 文档**（对方无）。

---

## 十四、总结

**双方都是全栈产品链**，各有护城河：我们在**运营侧（管理端+文档站+介绍页）+ OTA + 教务深度 + 零广告**领先；对方在**技术深度侧（服务端微服务 + 双端 + Widget + 推送 + AI + 工程化）**领先。

最关键的认知修正：**我们的 `login-proxy.md` 提案尚未完全落地**--后端代登录已实现（优于竞品），但"Token 封装 cookie"未实现（cookie 仍明文，安全性暂与竞品相当）。**补完这一步即可在登录安全性上超越竞品**，是最高优先级动作。

**行动建议**：
- **P0**：补完 login-proxy Token 封装（超越竞品安全性）+ 管理端鉴权 + 修 http bug + 请求队列。
- **P1**：代码生成 + CI/CD + forbidden-imports + 测试 + 修 tsc。
- **P2-P3**：成绩缓存+变更检测、React Query、课表日历订阅、空教室、工具箱云配置、验证码 OCR。
- **P4**：多厂商推送、LLM 解析通知、下线旧后端、落地页上线。
- **始终守住**：OTA + 后端代登录 + 管理端/文档站 + 零广告 + Zod/OP-SQLite + 教务深度。

> **核心一句话**：学对方的服务端工程化（错误码/singleflight/SHA256 变更推送/LLM 解析/代码生成/CI/CD）和高价值功能（空教室/日历订阅/云配置/推送/OCR），但绝不丢护城河（OTA、后端代登录、管理端+文档站、零广告、教务深度）--且首要任务是补完自己的 login-proxy Token 封装，在登录安全上反超对方。

---

# 附录：技术名词与设计范式普及

> 本附录面向不熟悉部分技术栈的读者，把正文中的设计范式与专有名词展开普及，并补充技术栈背景，结合双方对比讲清「是什么 / 解决什么问题 / 谁在用 / 效果」。读完成节即可对全文无生僻点。

## 附录 A：架构与设计范式

### A1. 微服务 vs 单体
一个应用的所有功能（登录、课表、成绩、推送……）放在一个进程里跑，叫**单体**；拆成多个独立的小服务、各自部署、通过网络互相调用，叫**微服务**。微服务好处是独立扩展（哪个模块忙就只扩哪个）、故障隔离（一个挂不全挂）、团队分头开发；代价是复杂度暴涨--服务之间怎么找到彼此（服务发现）、怎么追踪一次请求穿过了哪些服务（链路追踪）、怎么统一鉴权限流、部署运维都变重。
- **对方**：Go 用 CloudWeGo **Hertz**（Web 网关）+ **Kitex**（RPC 通信框架）拆成 **11 个微服务**，用 **etcd** 做服务发现（每个服务启动时把自己注册到 etcd，调用方从 etcd 查地址）。
- **我们**：NestJS **单体**一个服务全包。规模还小，单体够用且省心，但要注意模块边界清晰，避免日后拆分时粘连成团。

### A2. API 网关
微服务架构里，对外不暴露几十个内部服务，而是统一从一个「网关」进出：网关负责鉴权、限流、监控、把请求分发给后台各服务。客户端只认网关一个地址。
- **对方**：Hertz 就是网关，挂 Sentinel 限流（全局 5000 QPS）、Auth 鉴权中间件，再通过 Kitex RPC 调后台微服务。
- **我们**：NestJS 本身就是单一入口，天然承担网关角色，只是没有显式的限流。

### A3. remote-first 网关 + 本地兜底（我们独创）
这是我们客户端 `src/core/gateway/jw/run.ts` 的模式：每次请求教务，**优先走后端代理（remote）**，后端挂了（返回 502/503/504 或无响应）才**回退到客户端直连教务（local）**。好处是双保险：后端代理能突破「晚 11 点不准登录」的时段限制，后端万一宕机，App 仍能本地直连教务基础可用。竞品没有这个机制（纯客户端直连，受用户网络时段限制）。

### A4. 分层架构（controller / service / repository）
把代码按职责分层：**controller** 接收 HTTP 请求、**service** 写业务逻辑、**repository** 访问数据库。禁止跨层（页面不能直接摸数据库）。好处是职责清晰、可测试、可替换。我们 `best_practice.md` 推荐的数据流是 `screen -> hook -> feature api/repository -> core http/auth/db`，对方 server 是 `网关 -> RPC -> handler -> service -> db`，分层思想一致。

### A5. 状态机（finite state machine）
用一组**固定的状态**和**状态间的转移规则**来管理复杂对象的生命周期。比如认证状态可以是 `NoAccount`（没账号）-> `HasAccountNotAuthenticated`（有账号没登录）-> `Authenticated`（已登录），转移由具体事件触发（登录成功、cookie 失效）。好处是状态显式、不会出现「半登录」这种含糊态。
- **我们**：`createAuthCore` 把三套认证系统（教务/统一认证/考勤）抽象成**一个通用状态机**，支持订阅、并发去重（`pendingAuth`）。
- **对方**：jwch/yjsy 各管各的，没有统一抽象，是教训。

### A6. singleflight 防击穿
缓存失效的那一瞬间，如果有 100 个请求同时查同一份数据，它们都会发现「缓存没了」然后同时去打教务系统，可能把教务系统压垮--这叫**缓存击穿**。singleflight 的做法是：同一份数据的并发请求**合并成一次真实调用**，其余请求等这次结果出来共享。对方 `pkg/singleflight` 实现了这个（按学号合并），我们没有，值得学。

### A7. TaskQueue 异步任务队列
用户请求里有些操作不影响返回结果（比如写缓存、写数据库日志、发推送），如果同步做，用户要多等；扔到**后台队列异步执行**，请求立即返回，后台慢慢消化。对方 `pkg/taskqueue` 把缓存回写/DB 持久化/推送都异步化了，响应延迟最小化。我们目前是同步处理，可借鉴。

### A8. 请求队列 + 自动重登
token 过期时，如果有多个请求同时在飞，不能每个都去刷新一次 token（会乱）。正确做法：第一个发现过期的请求去刷新，**其余请求先入队暂存**，刷新成功后**批量重放**。业务层完全无感，不会看到 token 过期报错。
- **对方**：`api/axios.ts` 用 `refreshing` 标志 + `PendingTask[]` 队列实现。
- **我们**：`createAuthCore` 有 `pendingAuth` 去重，但请求层没做队列重放，且 `http.ts` interceptor 还有 bug（`return error` 而非 `reject`）。P0 待修。

### A9. 关注点分离 / 独立成库
把「教务系统爬虫」（脆弱、随教务改版频繁变动）从「业务后端」（鉴权、缓存、推送）里**抽成独立库**，各自版本化。教务改版时只升级爬虫库，不动业务发版节奏。对方 jwch/yjsy、我们 tool-adapter 都是这思路。教训：对方两库**复制演化**（本科研究生各抄一份改），维护翻倍，应先抽象统一接口再各自实现。

---

## 附录 B：数据库与存储

### B1. ORM（对象关系映射）三家：Prisma / gorm / TypeORM
用代码里的对象操作数据库表，不用手写 SQL。三方对比：
- **Prisma**（我们 tool-app-be 用）：TS 优先，用一份 `schema.prisma` 文件定义模型，类型安全极强，`prisma generate` 自动生成带类型的客户端。Prisma 7 是新版（驱动架构重写，更快）。
- **gorm**（对方 server 用）：Go 生态最主流 ORM，用 struct tag 定义字段。
- **TypeORM**（我们旧后端 GxuToolWebBE 用）：TS 老牌 ORM，装饰器风格，较重。

### B2. PostgreSQL vs MySQL
两大开源关系型数据库。MySQL 更普及、够用；**PostgreSQL** 功能更强（JSON 操作丰富、支持「生成列」、复杂查询优化好）。我们用 PG，对方用 MySQL 9。

### B3. GENERATED VIRTUAL 列（生成列）
数据库里**自动计算、不实际占存储**的虚拟列。对方 `follow_relation` 表用 `active_flag = IF(deleted_at IS NULL, 1, NULL)` 生成一个虚拟列，再配合唯一索引，优雅解决「软删除后能重新关注」的难题--普通唯一索引会因为软删除的旧记录占位，导致无法重新添加好友；用生成列让「已删除的记录」在该列变 NULL，唯一索引就忽略它们。是个精巧技巧。

### B4. JSON + SHA256 变更检测
成绩/课表数据存两份：**JSON 原文** + 它的 **SHA256 摘要**（一段数据的数字指纹，数据改一个字符指纹就变）。下次拉取新数据，算新指纹和旧指纹比对，**不同就是数据变了**。O(1) 检测变更，是对方触发「成绩更新推送」的核心机制（变了才推，没变不推，省推送配额）。我们后端不缓存数据，自然没有这个机制。

### B5. 移动端存储三件套：AsyncStorage / MMKV / OP-SQLite
- **AsyncStorage**：RN 自带的键值存储，异步、较慢、只能存简单 KV。对方**只用这个**（短板：复杂数据只能塞 JSON blob，无结构化查询）。
- **MMKV**：微信开源的 KV 存储，基于内存映射(mmap)，**极快**，我们用它存 OTA 版本号等高频小数据。
- **OP-SQLite**：RN 上的 SQLite，支持**复杂查询和结构化存储**（建表、索引、关联）。我们用它存评教模板/用户档案/成绩等结构化数据，是相对对方的优势。

### B6. Zustand（不是持久化）
澄清一个易混点：Zustand 是**内存里的**状态管理库（管理 UI 状态，App 关了就没了），不是持久化存储。持久化要靠上面三件套。我们和对方都用 Zustand 管内存状态。

### B7. Redis
内存数据库，专做**缓存**（热数据放内存，避免每次查库/查教务）。对方成绩缓存、推送队列、贡献者列表都缓存到 Redis。我们没有（实时代理，暂不需要，但要做成绩变更推送就得加缓存层）。

---

## 附录 C：认证与安全

### C1. JWT 双令牌（access + refresh）
**JWT**（JSON Web Token）是服务端签发的加密令牌，客户端带上它证明「我登录过」。双令牌机制：**access token**（短期，日常访问用）+ **refresh token**（长期，专门用来换新 access）。access 过期了用 refresh 换新，**用户不用重新登录**。对方用 access 7 天 / refresh 30 天。

### C2. Ed25519 非对称签名
签名算法分对称（同一把密钥加解密）和非对称（私钥签名、公钥验签）。**Ed25519** 是非对称签名里更现代更快的一种（比 RSA 快很多）。对方用它签 JWT（私钥在配置里，公钥验签）。我们后端目前用 cookie 模式没用 JWT。

### C3. 滑动续签
每次请求成功，服务端**顺手发一对新 token** 放响应头。只要用户持续用，access token 就一直被刷新，**永不过期**。对方 `Auth()` 中间件这么做。好处是用户无感（不会突然过期要重登），权衡是 token 一直有效（被盗风险持续）。

### C4. RSA / AES 密码加密
登录时密码不能明文传输，要加密。**RSA** 是非对称加密（教务系统给公钥，用公钥加密密码，只有教务系统私钥能解）--我们 `loginRSA` 和对方 jwch 都用教务系统公钥加密。**AES** 是对称加密（同一密钥加解密，更快）--我们考勤系统用 AES-ECB。注意对方 jwch 本科密码是 **MD5**（不可逆摘要），yjsy 研究生是 **Base64**（编码非加密），各校教务系统约定不同。

### C5. cookie 透传 vs Token 封装（核心安全差异）
- **cookie 透传**：每次请求带上原始 cookie 字符串（**明文**）。对方和我们当前都是这个。
- **Token 封装**：把 cookie 加密打包进一个 Token，客户端只存 Token、只传 Token，后端解封取 cookie 代理教务。cookie **不明文流转**，即使被中间人或日志泄露也无法直接用。
- 这就是我们 `login-proxy.md` 提案的核心：用 Token 封装 cookie。**实测未落地**（仍明文 cookie），补完即超越竞品。

### C6. 串号校验
登录后访问一次个人信息页，**比对页面上的学号和输入的学号是否一致**。教务系统偶尔会「cookie 串号」（你的 cookie 登录到了别人的账号），不校验就会泄露/错乱。对方 jwch 有 `CheckSession` 串号校验，我们没有，低成本高可靠，值得加。

---

## 附录 D：前端技术栈

### D1. Expo vs Bare RN CLI
React Native 有两种开发方式：
- **Expo**：官方推荐的框架套件，提供 **prebuild**（预生成原生工程）、托管配置、EAS 构建服务、大量现成原生模块，开发体验好、上手快，但受其生态约束。对方用 Expo SDK 56。
- **Bare RN CLI**：直接用 RN 脚手架，自己维护 `android/`/`ios/` 原生工程，控制力强、能深度定制原生，但繁琐。我们用这个。

### D2. Expo Router vs React Navigation
路由（页面怎么跳转）两套方案：
- **Expo Router**：**文件式路由**，文件路径就是路由（`app/(tabs)/index.tsx` -> 首页），类似网页框架 Next.js，还支持 `typedRoutes`（路由路径有类型提示）。对方用这个，更现代省心。
- **React Navigation**：**命令式配置**，在代码里定义路由栈和跳转。我们用这个，更灵活但要手写路由表。

### D3. NativeWind / Tailwind
**Tailwind** 是「原子化 CSS」--不写样式表，直接用预设 class 名写样式（如 `flex p-4 bg-white text-center`），快速且一致。**NativeWind** 把 Tailwind 带到 RN。对方用 NativeWind v4。我们用 @rneui 组件库 + 自研 un-ui，是另一种风格（组件化而非原子 class）。

### D4. shadcn/ui
不是传统「npm 装一个组件库」，而是一套**「把组件源码复制进自己项目」**的可定制方案，基于 Radix 无障碍原语。好处是组件代码完全在你手里，随便改。对方用 `@rn-primitives`（RN 版 Radix）+ shadcn 风格，`components.json` 是它的配置文件。这是近年前端很流行的组件方案。

### D5. TanStack React Query（服务端状态管理）
专门管「从服务器拿来的数据」的库：自动处理**缓存、重试、后台刷新、加载/错误状态**。数据是「用完即弃」的临时缓存，不用手动塞进全局 store。**选择性持久化**（`meta.persist`）= 只把标记的查询落盘，避免缓存爆炸又能离线可用。对方用它 v5，我们没有（手动管缓存/重试/状态，代码更累），P2 建议引入。

### D6. Zod（schema 校验）
TS 优先的数据校验库。定义一个 **schema**（数据结构描述），运行时校验「这个未知数据合不合规」。亮点：
- `safeParse`：不抛异常，返回 `{success, data/error}`，对脏数据友好。
- `.transform()`：校验时顺手重命名/转换字段。
- `z.infer`：**从 schema 反推 TS 类型**，一份 schema 同时是「运行时校验」+「编译时类型」，不用写两遍。
我们用 Zod 4（亮点），对方靠代码生成的类型，**没有运行时校验**（脏数据直接崩或错）。`tool-adapter` 也用 zod 做清洗。

### D7. cheerio vs htmlquery（CSS 选择器 vs XPath）
解析 HTML 的两种方式：
- **cheerio**：用 **CSS 选择器**（`#id .class div`，和前端写样式一样），jQuery 风格。我们 tool-adapter 用这个。
- **antchfx/htmlquery**：用 **XPath**（`//*[@id="xx"]//td[3]`，路径表达式），表达力强但语法晦涩。对方 jwch/yjsy 用这个。
两者各有千秋，CSS 选择器更直观，XPath 更灵活。

---

## 附录 E：代码生成与工程

### E1. OpenAPI / openapi-ts（接口代码生成）
**OpenAPI** 是一套 API 描述规范（用 YAML/JSON 把「有哪些接口、参数、返回」写清楚）。**openapi-ts** 从这份规范**自动生成前端的请求代码和 TypeScript 类型**。接口一改，重新生成，前后端永远对齐，杜绝「后端改了字段前端不知道」。对方用 Apifox（API 设计工具）导出 OpenAPI -> openapi-ts 生成 `api/generate/`，再用 `AsyncReturnType` 派生响应类型。我们手写 API 客户端，维护成本高。

### E2. Thrift IDL / hz / kitex（全链路代码生成）
**Thrift** 是接口定义语言(IDL)，描述数据结构和服务接口。**hz** 从 IDL 生成 Hertz 的路由/handler 骨架，**kitex** 生成 RPC 通信代码。对方服务端**全链路 IDL 驱动**：定义一次接口 -> 自动生成网关路由、handler、RPC client、类型，强类型贯穿全栈。我们无代码生成。

### E3. 双层 forbidden-imports（编译期约束）
禁止业务代码用某些导入（如 RN 原生 `Text`，因为它会跟随系统字体大小导致布局错乱，应改用统一封装的 `UnText`）。**双层**=两道关卡：
- **ESLint**：lint 时报错（但可能被忽略或跳过）。
- **Babel 插件**：**编译期直接抛错阻断运行**（绕不过）。
单一数据源 `forbidden-rule.js` 同时驱动两道。对方独创，强制全员用统一组件/主题，值得学。

### E4. CI/CD（持续集成 / 持续部署）
代码 push 后，机器自动跑 lint、类型检查、测试、构建、部署，不用人手操作。对方 GitHub Actions 全套：客户端（构建->alpha/beta->自动 bump version PR）、服务端（ci 五并行 job + 手动 deploy + codeql 安全扫描 + vulncheck 漏洞扫描 + dependabot 依赖更新）。我们**无 CI**（`best_practice.md` P4 已识别），P1 要补。

### E5. Swagger（在线 API 文档）
API 在线文档 + 可视化调试 UI。NestJS `@nestjs/swagger` 从代码自动生成，访问 `/docs` 就能看所有接口并在线试调。我们有（对方无在线 API 文档），是后端对接优势。

---

## 附录 F：推送 / AI / 其他

### F1. 友盟多厂商推送
国内 Android 推送的痛点：App 在后台会被系统杀掉，消息收不到。解法是接**各厂商官方通道**（小米/华为/vivo/oppo/荣耀），厂商通道在系统级常驻，能保证送达。**友盟 U-Push** 是统一推送平台，一套 SDK 对接所有厂商。**groupcast**=按标签广播；**tag**=给用户打标签（如「选了高数」），后端按 tag 精准推给特定群体。对方成绩变更推送就是给课程算 MD5 tag、按 tag groupcast，只有选了该课的学生收到。我们没有推送。

### F2. MCP Server（Model Context Protocol）
让 AI Agent 调用外部工具的**标准协议**。对方把教务查询（登录/查课表/查成绩等）暴露成 MCP 工具，AI 助手就能直接调这些工具帮用户查数据。是面向 AI 时代的前瞻设计。我们没有。

### F3. LLM 嵌入业务流程（最亮眼）
把大模型用于**具体业务任务**，不是做聊天机器人。对方的例子：教务处发「课程调整」通知（非结构化 HTML，人读才知道哪天调到哪天）-> 让 **LLM 读通知正文，提取结构化调课条目**（from_date/to_date 等）-> 根据校历映射到周次 -> 写进数据库 -> **人工审核后启用**。比人工读通知录规则高效百倍，又有审核兜底防 AI 出错。我们已有调课/调休/节假日通知模块，可升级为这种自动解析。

### F4. 青果代理 IP 轮换
频繁访问教务系统会被封 IP。**隧道代理**服务每次请求换一个出口 IP，规避封禁。对方 jwch/yjsy 内置「青果网络」隧道代理（环境变量开关）。我们思路不同：靠后端 24h 在校园网环境（教务系统对校内 IP 宽容），不轮换 IP。

### F5. OTA 热更新（我们的核心优势）
**OTA**（Over-The-Air）= 不发新 APK 安装包，只更新 **JS bundle**（业务逻辑代码），用户下次启动 App 即生效。能秒级推送 bugfix，绕过应用商店审核。我们自研 JS bundle 级 OTA（`file.unde.site` 托管 version.json + bundle），**对方完全没有**，每次更新都得发整包。这是碾压级差异。

### F6. 桌面 Widget 多形态
- **iOS WidgetKit**：iOS 桌面小组件，Swift 原生实现。
- **iOS ControlWidget**：iOS 18+ 控制中心小组件（下拉控制中心那种），对方做了「直达一码通」。
- **Android AppWidget**：Android 桌面小组件，Java/Kotlin 原生实现。
对方三种都是**原生**实现（性能好、形态多，但开发成本高、需 Swift/Kotlin）。我们用 `react-native-android-widget` **JS** 实现（开发快但形态少、性能弱）。

### F7. etcd / Sentinel / OpenTelemetry（服务端三件套）
- **etcd**：分布式键值存储，常做**服务发现**（微服务注册/查找彼此）。对方用它。
- **Sentinel**：阿里开源**限流熔断**库，控制 QPS 防过载。对方全局限 5000 QPS。
- **OpenTelemetry**：可观测性标准（统一链路追踪+指标+日志），对接 Tempo（追踪）/Loki（日志）/Prometheus（指标）/Grafana（可视化）。对方全套配置（部分注释未落地），我们没有。

---

> **阅读建议**：若只想看结论与行动，读〇、二、六、十二节即可；若想理解每个技术决策的来龙去脉，对照本附录回看正文。本报告所有结论均以实测代码为据，关键证据标注了文件路径，可按图索骥去 `D:\coding\fzuapp\`（竞品）与各仓库（我们）核对。
