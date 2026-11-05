# Agent A 状态

- 当前 Phase：Phase 0 完成（已发布 [bootstrap]），Phase 1 进行中
- 已完成：
  - ios-native 骨架、project.yml、全部 package 空壳、契约 v1（GxuFoundation/Networking/Auth/Storage/TestSupport）
  - BackendClient（含会话失效检测、自动重登一次并重试）、JwSessionManager（actor，并发重登合并）、AccountCenter、Keychain/内存 CredentialStore
  - build.sh / test.sh / capture-fixtures.sh；GxuCore 单测通过；App 在 iPhone 18 Pro 模拟器启动，三标签正常
- 进行中：Phase 1 剩余项——FeatureAccount 教务登录页（设置 → 教务账号）、真实后端联调、AccountCenter 与登录页截图自查
- 阻塞：
  - 需要用户提供 `.secrets/account.env` 才能跑 capture-fixtures.sh 并联调真实登录
  - 需要用户在 project.yml 填 DEVELOPMENT_TEAM（真机、App Group、Keychain 共享）
- 给其他 agent 的通知：见 COORDINATION.md「[bootstrap] 契约 v1 已发布」（AppServices 在 GxuAuth；Environment 默认值是 unconfigured，预览用 `.preview`）
- 环境备注：xcode-select 指向 CommandLineTools，脚本自动使用 /Applications/Xcode.app（Xcode 27.2，iOS 27.2 SDK，没有 iPhone 17 Pro，优先选 iPhone 17 Pro，否则取第一台 iPhone）
- TODO(verify)：
  - 后端 `/jw/login` 失败时的状态码和 body 格式（目前按 `{message|msg}` 取文案）
  - 登录响应 Set-Cookie 是否同时含 JSESSIONID 和 route（按 RN 逻辑假设）
  - 后端会话失效时的真实表现（目前判定：401 / 302 到 login / HTML 登录页）
  - Keychain access group 尚未启用（GxuConfig.keychainAccessGroup = nil），填 Team ID 后再开
