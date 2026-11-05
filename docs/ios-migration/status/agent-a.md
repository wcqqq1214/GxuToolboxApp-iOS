# Agent A 状态

- 当前 Phase：Phase 2（Phase 1 已验收 [phase1-accepted]；考勤认证已交付，进行 CA 统一认证 / PEC / xlzxms）
- 已完成：
  - ios-native 骨架、project.yml、全部 package 空壳、契约 v1（GxuFoundation/Networking/Auth/Storage/TestSupport）
  - BackendClient（含会话失效检测、自动重登一次并重试）、JwSessionManager（actor，并发重登合并）、AccountCenter、Keychain/内存 CredentialStore
  - build.sh / test.sh / capture-fixtures.sh；GxuCore 单测通过；App 在 iPhone 18 Pro 模拟器启动，三标签正常
  - FeatureAccount：`AccountFeature.makeRootView()` = 教务账号页（登录 / 已登录显示学号 + 退出），含 view model 单测；浅色/深色模拟器截图已自查
- 进行中：真实后端联调（需要测试账号）；Shell（B）把 `AccountFeature.makeRootView()` 挂到「设置 → 教务账号」
- 阻塞：
  - 需要用户提供 `.secrets/account.env` 才能跑 capture-fixtures.sh 并联调真实登录
  - 需要用户在 project.yml 填 DEVELOPMENT_TEAM（真机、App Group、Keychain 共享）
- 给其他 agent 的通知：见 COORDINATION.md「[bootstrap] 契约 v1 已发布」（AppServices 在 GxuAuth；Environment 默认值是 unconfigured，预览用 `.preview`）
- 环境备注：xcode-select 指向 CommandLineTools，脚本自动使用 /Applications/Xcode.app（Xcode 27.2，iOS 27.2 SDK，没有 iPhone 17 Pro，优先选 iPhone 17 Pro，否则取第一台 iPhone）
- 真实后端已验证（2026-11-05，测试账号）：
  - `POST /jw/login` 成功返回 **201**，`{"code":200,"message":"success","data":null}`，两个独立的 Set-Cookie（JSESSIONID、route，Path=/，Max-Age=7 天）
  - 账号错误 → **401** `{"code":401,"message":"账号或密码错误，登录失败"}`；会话失效/无 Cookie → **401** `{"code":401,"message":"登录态过期，请重新登录"}`（所以 401 判定足够）
  - 临时联调测试：登录 → 取数 → 破坏 Cookie 后自动重登 → 错误密码，全部通过（测试已删除，未提交）
  - `/jw/*` 响应形如 `{code, message, data}`，`DataEnvelope` 可直接解
- Fixture 已抓到 `Fixtures/raw/`（gitignore）：schedule_personal、profile_startDay、exam、score、score_usual、profile
- 本轮完成：脱敏 fixtures（已发布）；`services.profiles`（ProfileRepository）；term=3 结论 + `AcademicTerm.isBackendQueryable`；DEBUG 自动登录 + `scripts/run-e2e.sh`；模拟器选择规则；PLAN §5.1；ad-hoc 签名验证（App Group / Keychain 可用）
- 给用户：模拟器开发不需要真实 Team ID；真机运行和 Keychain access group 才需要，到时在 project.yml 把 `YOUR_TEAM_ID` 换成真实值
- TODO(verify)：
  - 小组件扩展运行时是否读到同一个 App Group 容器（需 C 在 Widget 里实测）
  - `/jw/score/usual` 带课程 id 的真实响应尚未抓取
  - Keychain access group 尚未启用（GxuConfig.keychainAccessGroup = nil），填真实 Team ID 后再开
  - project.yml 的 DEVELOPMENT_TEAM 目前是占位 `YOUR_TEAM_ID`
  - test.sh 偶发 `xcrun: unable to find utility simctl`（连续启动多个 xcodebuild test 时），重跑即可

## Phase 2 进度（2026-11-05）
- 完成：Phase 1 验收（run-e2e-ui.sh，浅色/深色各 9 步通过）；每个 worktree 专属模拟器；考勤认证（AttendanceSession、`Authorization: Token` 注入、401 → signedOut、考勤账号页、单测）
- 完成：CA 统一认证（ZfcaRSA + UnifiedAuthSession）、PEC / xlzxms SSO、统一认证账号页、ATS 例外（已发布，待真实账号验证）
- 完成：WebView 容器、版本检查（等 version.json 增加 ios 通道）、反馈 + 埋点、个人信息页（均已发布，待 B 在设置页挂载）
- 需要用户：**`.secrets/account.env` 里补 `CA_USER`、`CA_PASS`（统一认证账号）**才能真实验证 CA / PEC / xlzxms；另需一个考勤系统账号 + 人工看验证码才能验证考勤完整登录（目前只验证了验证码接口，登录流程由单测覆盖）
- TODO(verify)：考勤 `/attendance/login` 的真实响应（code 600 / token / userInfo.userId）；验证码错误时的 msg 文案
- 后端问题（需用户处理）：`GET /feedback/{userId}` 一律 401 "看板：未登录或登录已过期"（真实验证，带有效教务 Cookie 也一样），"我的反馈"无法查看
- 需要用户：version.json 增加 `ios` 通道；`.secrets/account.env` 补 `CA_USER`/`CA_PASS`
- TODO(verify)：WebView 带统一认证 Cookie 访问 OA 的实际效果（Phase 3 OA 文件时验证）
