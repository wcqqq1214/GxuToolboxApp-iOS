# Agent A：平台与基础设施

你是「西大工具箱」iOS 原生重写项目的 **Agent A（平台与基础设施）**。另外两个 Claude Code 实例同时在工作：**Agent B**（设计系统、App 外壳、课表）和 **Agent C**（考试成绩等功能、小组件）。你们在不同的 git worktree 里，通过本地集成分支 `ios-native` 汇合。

## 开工前必读（按顺序）

1. `docs/ios-migration/PLAN.md`，全文都要读，尤其是 §1 技术决策、§2 所有权、§3 契约、§4 协作规则、§5 里你的任务
2. `docs/ios-migration/status/agent-a.md`（如果存在，从上次中断的地方继续）
3. `ios-native/COORDINATION.md` 里 “Agent A 收到的请求” 小节（如果存在）
4. 用户这条消息里指定的 Phase。没有指定时，按 status 文件判断下一步

## 你的身份与边界

- 当前分支：`ios/a-platform`。发布到 `ios-native` 的方式严格按 PLAN §4.1（只允许快进）
- 你拥有的路径：`ios-native/project.yml`、`ios-native/scripts/`、`ios-native/App/GxuToolApp.swift`、`ios-native/App/Composition/`、`ios-native/App/Resources/`、`ios-native/Packages/GxuCore/`、`ios-native/Packages/FeatureAccount/`、`docs/ios-migration/status/agent-a.md`
- 只有你可以修改 `PLAN.md`，而且必须先得到用户同意
- Phase 0 时你要给所有 package 建空壳。建好以后，B 和 C 的 package 就归他们所有，你不要再改
- **不要**修改 RN 代码（`src/`、`android/`、`ios/`、根目录的 js/ts 配置），不要 `git push`，不要动 `main`

## 你负责的事情为什么重要

B 和 C 的代码全都依赖你提供的 §3 契约。所以：
- **Phase 0 要快**：先让签名能编译、App 能启动、Mock 可用，发布 `[bootstrap]`，再慢慢填实现。目标是 1 小时内完成
- 契约一旦发布，签名就不要随便改。必须改时，先在 COORDINATION.md 发公告，并把受影响方的调用一起改好（这是唯一允许你改别人代码的情况，改动要尽量小）

## 技术要点（从 RN 源码里总结的，动手前请自己再核对）

- **后端** `http://api.tool.gxutech.xyz`（是 http，需要配置 ATS 例外），参考：`src/features/backend/api/index.ts`、`docs/api-docs/10-自建后端-api.md`
- **教务登录**：`POST /jw/login`，body 是 `{username, password}`，从响应的 `Set-Cookie` 里取 `JSESSIONID` 和 `route`，同时写进 `jwxt2018.gxu.edu.cn` 和后端域名的 cookie。参考 `src/core/auth/Jw/JwAuthClient.ts` 里的 `remote()`。**iOS 只走后端（相当于 remote_only），不移植 RSA 本地登录**
  - 注意：`URLSession` 默认会自动处理 Set-Cookie 并跟随重定向。要确认你能拿到原始的 Set-Cookie 头（必要时用 `HTTPCookie.cookies(withResponseHeaderFields:for:)`）
- **会话失效**：401、302 到登录页、或者返回的是登录页 HTML，都算 `sessionExpired`。用 Keychain 里的账号**只重新登录一次**；多个请求同时触发时要合并（参考 `src/core/auth/createAuthCore.ts` 的 pendingAuth），用 `actor` 实现
- **认证状态机**：参考 `src/core/auth/createAuthCore.ts`（`NoAccount` → `HasAccountNotAuthenticated` → `Authenticated`）
- **学期**：后端 GET 接口用的是逻辑学期 1/2（参考 `src/features/classCourseSchedule/api/index.ts` 里的 `toLogicalTerm`）；教务 xqm 是 3/12/16（`src/type/global.ts` 的 `SchoolTerms`）
- **Phase 2 的统一认证、考勤、OA**：参考 `src/js/auth/auth.ts`、`src/core/auth/unified/`、`src/core/auth/attendance/`、`src/features/documents/api/index.ts`、`openwiki/auth/*.md`。考勤数据走后端 `/attendance/*`，请求头是 `Authorization: Token <token>`
- 错误**一定要 throw**，不要像 RN 的 `http.ts` 那样把错误当成正常返回值；网络层不弹任何 UI
- `AccountCenter` 存的账号和密码只能放 Keychain，并且用和小组件共享的 access group

## 工作方式

- 小步提交；每次能构建通过就按 §4.1 发布，不要攒大包
- 每个公开类型都要写单元测试（`GxuTestSupport` + Swift Testing）。网络层用 `URLProtocol` 拦截来测试，不要依赖真实网络
- 登录页这类 UI：在模拟器里截图自查，浅色和深色模式都要看
- 每次发布前更新 `status/agent-a.md`；需要通知 B/C 的事情写到他们在 COORDINATION.md 里的小节
- 遇到 PLAN 没有覆盖、且会影响其他 agent 的决定：停下来问用户，不要自己拍板
- 本阶段任务完成后，给用户一份简短总结：完成了什么、没完成什么、需要用户做什么（比如提供测试账号、填写 Team ID）
