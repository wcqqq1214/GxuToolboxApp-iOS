# Agent A 状态

- 当前 Phase：Phase 3 的 A 部分已完成（[phase3-done] A）；App 图标和名称等用户决定的项见 PLAN §7
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

## 2026-11-05 晚：协调者指令后的进展
- PLAN §1 / §5.1 (f)(g)(h) / §7 已更新并发布；`_env.sh` 在 rebase / detached 时从 rebase 状态或 worktree 目录名解析专属模拟器（不再新建 `gxu-detached`，已确认无人使用后删除）
- 用户补充决定已落实：节假日不再待办；CA / 考勤真实账号验证改为后续测试；隐藏「我的反馈」入口（开关默认关闭）；version.json 没有 `ios` 通道时静默
- **iOS 18 降级走查：当前无法安装 runtime（阻塞）**。磁盘空间足够（可用约 55 GiB，runtime 约 8.9 GB），但 Xcode 27.2 的下载目录里没有 iOS 18：`xcodebuild -downloadPlatform iOS -buildVersion 18.0…18.6`（含 `-architectureVariant arm64` 和构建号 22G86）全部返回 "not available for download"；Apple 旧版目录里的 iOS 18.6 条目是 `mobileAsset` 方式，没有可直接下载的地址。可选办法（需用户决定）：① 另装一个 Xcode 16.x（约 3–5 GB 安装包，需 Apple ID 下载，可用 `xcodes`）并用它下载 iOS 18 runtime；② 退而求其次，让 B 在 GxuDesign 里加一个 DEBUG 开关强制走 `#available(iOS 26)` 的降级分支，在 iOS 27 模拟器上审查降级外观（只能发现样式问题，不能替代真 runtime）

- Phase 2 验收：light / dark / legacy 各一遍通过；1 项界面小问题已写进 C 的请求区（成绩、GPA 标题被挤）；CA、考勤完整登录标「后续测试」；iOS 18 runtime 仍装不到（见上）

## Phase 3（A，2026-11-06）— 已完成，[phase3-done] A
- 完成并发布：OA 文件（列表 / 类型筛选 / 标题搜索 / 分页 / 详情正文 / PDF·DOCX 预览）、OA 账号、问卷系统 wjxt（待阅文件）、本机脱敏错误日志 + 诊断日志页、隐私清单（App + Widget）、ATS 复查（后端改走 HTTPS，移除其 ATS 例外）、`scripts/archive.sh`、`scripts/build.sh release`；干净 Release 构建抓到并修复了 `import FeatureExam` 问题
- 全部 package 测试通过（`scripts/test.sh`）；`build.sh` 和 `build.sh release` 通过
- **后续测试（不算未完成）**：OA / wjxt 真实登录与取数（这台机器访问 OA 返回 403 页面、wjxt 无响应，疑似只允许校内网络；也没有 OA 账号）、CA / PEC / 工程训练中心、考勤完整登录；PEC / 工程训练中心能否改用 https 以收紧 ATS；`archive.sh` 的 archive / 上传步骤（需要真实 Team ID）
- 留给用户（PLAN §7）：App 图标和名称；隐私清单声明的复核与隐私政策链接；Team ID；`version.json` 的 `ios` 通道
- 待 B 挂载：工具箱 `oaFiles` → `AccountFeature.makeOAFilesView()`；设置里的 OA 账号、诊断日志（见 COORDINATION 的 B 请求区）
- **截图（不入库，DEBUG 直达页面，OA 数据为示例，不含真实数据）**：
  - OA 文件列表（示例数据）：`/Users/wcqqq1214/Project/gxu_ios_a/ios-native/.screens/screen-oaFilesDemo-light.png`、`/Users/wcqqq1214/Project/gxu_ios_a/ios-native/.screens/screen-oaFilesDemo-dark.png`
  - OA 文件详情（示例数据，正文 HTML + 附件按钮）：`/Users/wcqqq1214/Project/gxu_ios_a/ios-native/.screens/screen-oaDetailDemo-light.png`、`/Users/wcqqq1214/Project/gxu_ios_a/ios-native/.screens/screen-oaDetailDemo-dark.png`
  - OA 文件未登录引导：`/Users/wcqqq1214/Project/gxu_ios_a/ios-native/.screens/screen-oaFiles-light.png`；OA 账号页：`/Users/wcqqq1214/Project/gxu_ios_a/ios-native/.screens/screen-oaAccount-light.png`
  - 诊断日志（示例记录，展示脱敏效果）：`/Users/wcqqq1214/Project/gxu_ios_a/ios-native/.screens/screen-errorLog-light.png`

## Phase 3 验收（A，2026-11-06）— [phase3-accepted]
- 浅色 / 深色 / legacy 各一遍 phase3 走查通过；规则核对和附录 A 逐项状态见 COORDINATION「[phase3-accepted]」；2 项界面小问题写进 B 的请求区
- 走查脚本：`scripts/run-e2e-ui.sh <light|dark> phase3 [legacy]`（按 RN 工具箱名称，兼容旧名称；入口是切换标签时自动回到出发标签；自动扫描「号座」和「学年第一学期」文字）
- 截图：`/Users/wcqqq1214/Project/gxu_ios_a/ios-native/.screens/ui-light-050129/`、`ui-dark-050625/`、`ui-light-legacy-051057/`

## 代码审查（pstack interrogate）— 第 1 轮后停止，决策日志（A，2026-11-06）
- 范围：A 的路径（GxuCore、FeatureAccount、App/Composition、scripts / project.yml / 隐私清单 / fixtures），3 个对抗 subagent。**用户决定审查循环到此结束，没有发 `[review-*]` 公告。**
- **已验证并修复（a94f5df，每条有回归测试）**：OA 列表快速切换筛选时旧请求覆盖新结果、页码被推进导致「加载更多」跳过第 2 页（`OAFilesModel` 加代数令牌，反馈列表同形态一并修）；`OASession.download` 用 `hasSuffix("gxu.edu.cn")` 导致 `evilgxu.edu.cn` 通过并收到 Bearer token（改为真正的子域判断，token 只发给 `oa.gxu.edu.cn`）；下载文件名可逃出临时目录且没有扩展名（清洗文件名、每次一个独立目录、按 Content-Type / 调用方补扩展名）；`ErrorLog.redact` 漏掉 JSON 字段、`accessToken` / `access_token`、值里带 `;` `,` 空格、整行 Cookie、`密码：`、带分隔符的手机号；查询串里的 `+` 没编码（新增 `QueryString`，BackendClient / OASession / CAS service 都改用，和 JS 的 `encodeURIComponent` 一致）；静默重登进行中退出登录会把已退出的会话写回（`JwSessionManager` 加退出代数，迟到的登录结果作废，`AccountCenter` 忽略退出后的迟到通知）；退出 OA / 换 OA 账号时 wjxt 的 Cookie 还在（新增 `WjxtSession.clear()`）；后端返回极端的 `study_years` / `grade` 会让 `academicYears` 溢出崩溃（限制范围、加法改为溢出安全、`ProfileRepository` 拒绝异常值）。
- **未验证，真机后再看（第 3 个 reviewer 报告的 5 条，我没有重跑也没有修）**：
  1. `Info.plist` / `Widget/Info.plist` 里的版本号和构建号是写死的 `1.0` / `1`，`MARKETING_VERSION` 和 `BUILD_NUMBER` 不起作用，第二次上传 TestFlight 会因构建号重复被拒，埋点和反馈的 `appVersion` 也永远是 1.0（建议改成 `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`）；
  2. `sanitize-fixtures.py` 只按 `,;，；` 切分教师姓名，遇到 `、` 分隔会漏掉一个名字，而且残留检查看不出来（已提交的 fixture 没有这个问题，是以后抓数据的盲区）；
  3. `sanitize-fixtures.py` 的假 `teacherId`（和 `qq_map`）按排序编号，出现新教师会让已发布的编号整体移位；
  4. `archive.sh` 里 `.secrets/archive.env` 会覆盖显式给的 `DEVELOPMENT_TEAM` 环境变量（`run-device.sh` 已经按「环境变量优先」写）；
  5. `archive.sh --check` 不接受 project.yml 里不带引号且带行尾注释的 Team ID。
- 没做：第 2 轮及以后的审查；`[review-clean]` / `[review-stopped]` 公告。a94f5df 是 rebase 后未构建就发布的，真机准备这一步重新构建验证。

## 真机验证准备（A，2026-11-06）
- `scripts/_env.sh`：**`gxu--` 模拟器的原因**——老代码用 `tr '/ ' '--'` 拼名字，分支名 / 目录名一旦解析成单个标点（例如 `basename /` = `/`，来自 git 解析失败的 worktree 或临时 worktree 被删），名字就变成 `gxu--` 并被新建出来（创建时间 03:39，当时没有 worktree 在用它）。现在名字只保留字母数字和 `._-`，清洗后为空、或 `ios-native` 目录里没有 `project.yml` 就**报错退出，不再新建**；`gxu--` 已确认无人使用后删除。我没能复现出触发它的那一次具体运行（临时 worktree 已被清理）。
- `scripts/run-device.sh`：`--check` 只检查前置条件；否则用真实 Team ID 自动签名构建 App + Widget（不加 ad-hoc 签名）、`devicectl` 安装并启动；Team ID 来自环境变量或 `.secrets/archive.env`，环境变量优先，**不写进 git**，`project.yml` 里仍是占位符；`devicectl` 会把本机的模拟器也列出来，脚本按 `reality = simulated` 排除。没有 Team ID / 没有真机时，`--check` 给出明确提示（已在本机验证）；构建、安装、启动这几步**没有真机，未验证**。
- Keychain access group：`GxuConfig.keychainAccessGroup` 现在读 Info.plist 的 `GxuKeychainAccessGroup`（`$(AppIdentifierPrefix)com.gxutool.ios`，App 和 Widget 都有），只在真机、且展开后带 10 位 Team ID 前缀时才返回（`TEAMID.com.gxutool.ios`）；模拟器和 ad-hoc 签名返回 nil，行为不变。纯函数 `resolveKeychainAccessGroup` 有单测；真机上能否读写**未验证**（清单 4.1）。
- `docs/ios-migration/device-checklist.md`：真机清单（小组件 / Live Activity / App Intents、Dynamic Type 和 VoiceOver、需要账号或校园网的功能、Keychain 和后台 / 回前台刷新、上架前的真实 iOS 18 和 archive.sh），每项有步骤、预期结果和操作人。
- 追加（用户要求）：`ios-native/.secrets/archive.env.example` 模板（只有 `DEVELOPMENT_TEAM=XXXXXXXXXX` 是必填，其余是注释掉的可选项；本机 `.git/info/exclude` 也排除了 `.secrets/`，所以模板是 `git add -f` 加进去的，`.gitignore` 里也加了 `!.secrets/*.example` 例外）；`run-device.sh --ipa`：Debug 配置（不上报埋点）自动签名 archive → 导出 development 方法的 `.ipa` 到 `ios-native/build/export/`，结束时打印绝对路径和三种安装方式；没有 Team ID 时给出明确提示，不需要设备在线（没连设备只给提示）。**archive / export 这两步没有 Team ID，未验证**；`--ipa --check`、ExportOptions 的 plist 语法已在本机验证。Bundle ID 目前固定，模板里写明改不了。
- 验证（rebase 到 eae15bf 之后）：`build.sh`、`scripts/test.sh`（8 个 package）、`build.sh release` 全部通过，a94f5df 确认没问题。

## 免费账号真机（`--personal`）（A，2026-11-06）
- `scripts/run-device.sh --personal`：Team ID 自动取（Xcode 账号 → 钥匙串证书，`scripts/detect-team.py`，只用 ID，打印时打码，`--self-test` 有假数据测试）；`BUNDLE_ID` 可由环境变量 / `.secrets/archive.env` 覆盖（`project.yml` 新增构建设置 `GXU_BUNDLE_ID` / `GXU_APP_GROUP` / `GXU_KEYCHAIN_GROUP`，默认值不变，已确认模拟器构建的标识和 entitlements 没变）；先按完整能力签名，Xcode 报「不支持」才自动降级（`CODE_SIGN_ENTITLEMENTS` 换成空 entitlements、`GXU_APP_GROUP=`、`GXU_KEYCHAIN_GROUP=`，只在这次命令行里生效）；`--self-test` 用 Apple 报错的真实措辞测了降级判断和「Bundle ID 被占用」判断。
- 运行时回退：`GxuConfig.appGroupID` 改为读 Info.plist（`GxuAppGroupID`），空值 = 不使用 App Group；`AppDatabase.databaseDirectory` 在没有 App Group 或拿不到容器时用 Application Support；`UserDefaultsSharedStore` 在 App Group 容器拿不到时用 `.standard`（显式传入的其他 suite 不受影响）。小组件本来就会在没有快照时显示 `.empty(.missingSchedule)`。有单元测试。**模拟器不校验 App Group entitlement（对任何 group id 都返回容器路径），所以「真的没授权」只能在真机上验证。**

## 登录修复 [login-fix]（A，2026-11-06）
- 统一认证：`testToken()` 不跟随重定向是根因（登录成功后校验接口第一跳 302，被判成失败）；已改为跟随跳转链并加回归测试；验证码状态接口 `getKaptchaStatus` 返回 true 时不再提交；失败文案按原因分类，只有服务端明确说账号密码有问题才这么说；诊断日志写步骤 / 状态码 / 最终主机路径。**教训：** 之前的单测没有覆盖 `login(username:password:)` → `testToken()` 这条路径，stub 也没模拟 302 链，所以漏了；`RN 的 testToken 在 RN 里靠 XHR 自动跟随重定向` 这个隐含前提当时没有写进测试。
- OA：请求格式和 RN 一致（只有 `Content-Type: application/json`），没改；按 403 / 非 JSON / `code != 200` / 缺 token / 其他状态码分别给文案并写诊断日志；服务端明确拒绝时转述它的 `message`。
- 没有证据的不改：没有用任何真实账号尝试，没有读 Keychain 里的密码。
