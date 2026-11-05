# 西大工具箱 iOS 原生（SwiftUI）重写方案

> 本文件是 3 个并行 agent 的**唯一事实来源**。所有 agent 开工前必须通读。
> 修改本文件只允许用户或 Agent A（经用户同意）进行；其他 agent 有异议写到 `ios-native/COORDINATION.md`。

## 0. 背景与目标

- 现状：RN 0.84 应用实际只发布 Android（见 `AGENTS.md`）。`ios/` 是 RN 默认脚手架，从未上架。
- 目标：在 `ios-native/` 下用 **纯 SwiftUI** 重写 iOS 版，采用 iOS 26 **Liquid Glass** 设计语言；Android 继续由 RN 维护。
- 原则：
  1. **厚后端、薄客户端**。凡是自建后端 `api.tool.gxutech.xyz` 已经代理的教务/考勤接口，iOS 端一律走后端（相当于 RN 的 `remote_only`），**不移植** RN 的本地 HTML 解析兜底。
  2. 只有后端没覆盖的系统（CA 统一认证、PEC、xlzxms、OA、prof 教师信息、wjxt）才在 Swift 里直连。
  3. 不照搬 RN 的遗留结构（`src/js`、`src/class`、`src/screens`），只移植**行为**。RN 代码是参考资料，不是模板。
  4. 修正 RN 中已知的问题：成绩缓存不区分账号、错误被吞成 fulfilled、底层弹 Toast 等（见 `AGENTS.md`、`openwiki/`）。

## 1. 已定技术决策（agent 不得自行更改）

| 项 | 决策 |
|---|---|
| 工具链 | Xcode 27.2（本机实际版本；原计划写的是 Xcode 26），Swift 6 语言模式，开启严格并发检查。本机原本只有 iOS 27.2 模拟器 runtime，iOS 18 runtime 需另装（见 §5.1 (h)） |
| 最低系统 | **iOS 18.0**。所有 iOS 26 才有的 API（`glassEffect`、`GlassEffectContainer`、`tabBarMinimizeBehavior`、`tabViewBottomAccessory` 等）**只能出现在 `GxuDesign` 内部**，用 `if #available(iOS 26, *)` 包装，并在 iOS 18 上降级为 Material |
| UI | SwiftUI 优先；只有确实做不到时才用 UIKit 桥接（例如 `WKWebView`） |
| 状态 | `@Observable` + Swift Concurrency（`async/await`、`actor`）。不用 Combine，不用第三方状态库 |
| 工程生成 | **XcodeGen**（`ios-native/project.yml`），`.xcodeproj` 不进 git，避免多人冲突 |
| 模块化 | 本地 Swift Package，每个 package 有唯一的所有者（见 §2） |
| 第三方依赖 | 只允许 **GRDB.swift 7.x**（SQLite）和 **SwiftSoup**（HTML 解析）。要加其他依赖，必须先写进 COORDINATION.md 并经用户同意 |
| 本地存储 | 结构化数据：GRDB（App Group 容器里的 `gxu_tool.sqlite`）；轻量 KV：App Group 下的 `UserDefaults(suiteName:)`；密码与 token：Keychain（access group 与小组件共享） |
| 网络 | `URLSession` + 共享 `HTTPCookieStorage`；需要禁止重定向时用 `URLSessionTaskDelegate` |
| 测试 | Swift Testing（`import Testing`），用 JSON fixture 测解码和业务逻辑 |
| 图标 | 只用 SF Symbols |
| Bundle ID | 先用占位 `com.gxutool.ios`，App Group `group.com.gxutool.ios`，Team ID 由用户在 `project.yml` 填写 |
| ATS | 后端是 `http://`，需要为 `api.tool.gxutech.xyz` 配置 `NSExceptionDomains`（长期应推动后端上 HTTPS） |

## 2. 目录结构与所有权

```
ios-native/
├── project.yml                         [A]
├── COORDINATION.md                     [共享，只能在自己的小节下追加]
├── scripts/                            [A]  build.sh / test.sh / capture-fixtures.sh
├── Fixtures/raw/                       [A]  抓取的原始响应，已 gitignore
├── App/
│   ├── GxuToolApp.swift                [A]  @main 入口
│   ├── Composition/                    [A]  AppServices 组装、依赖注入
│   │   └── FeatureRegistry.swift       [共享，各 feature 只能增改自己那一行]
│   ├── Shell/                          [B]  RootView、TabView、导航、工具箱和设置的索引页
│   │   └── ToolboxCatalog.swift        [共享，各 feature 只能增改自己那一行]
│   └── Resources/                      [A]  Info.plist、entitlements、Assets.xcassets
├── Widget/                             [C]  WidgetKit + Live Activity extension
└── Packages/
    ├── GxuCore/          [A]  targets：GxuFoundation、GxuNetworking、GxuAuth、GxuStorage、GxuTestSupport
    ├── GxuDesign/        [B]  主题、玻璃组件封装、通用状态视图
    ├── FeatureAccount/   [A]  账号登录与管理、个人信息、反馈、版本、WebView 容器、OA 文件
    ├── FeatureSchedule/  [B]  products：ScheduleKit（无 UI，小组件可用）、ScheduleUI
    ├── FeatureCampus/    [B]  班级课表、全校课表、实践课（物理实验/工程训练）、地图楼层
    ├── FeatureExam/      [C]  考试信息、成绩、平时分、GPA 计算
    ├── FeatureCourse/    [C]  已选课程、选课策略、调课通知、节假日、教学评价
    └── FeatureMisc/      [C]  考勤界面、教师查询
```

规则：
- **只能修改自己拥有的路径。** 标为 [共享] 的文件只能增改与自己 feature 相关的行。
- 每个 feature package 对外只暴露：`public enum XxxFeature { static let migrations: FeatureMigrations; static func makeRootView(...) }` 以及需要共享的模型。
- 需要别人提供的东西（新 API、组件、字段）：写到 `COORDINATION.md` 里**对方的** “收到的请求” 小节；对方完成后打勾。
- 在对方交付前，先在自己的 package 里写一个 `internal` 的临时实现顶上，注释 `// TEMP(coord-#n)`，等对方交付后删除。

## 3. 共享契约 v1（Agent A 在 Phase 0 先实现这些签名）

B 和 C 照着这些签名写代码，A 必须保证签名一致。要改签名，先在 COORDINATION.md 发公告。

```swift
// ── GxuFoundation ──
public enum AuthSystem: String, Codable, Sendable, CaseIterable { case jw, unified, attendance, oa }

/// 逻辑学期：1 = 秋季（教务 xqm=3），2 = 春季（xqm=12），3 = 小学期（xqm=16）
/// 与后端 GET 接口里的 `term` 参数一致（参考 RN 里的 toLogicalTerm）
public struct AcademicTerm: Hashable, Codable, Sendable, Comparable {
    public var year: Int        // 学年起始年，例如 2025 表示 2025-2026 学年
    public var term: Int        // 1 / 2 / 3
    public var jwXqm: String { get }
    public var displayName: String { get }   // 例如 "2025-2026 秋季学期"
}

public enum GxuError: Error, Sendable, Equatable {
    case notLoggedIn(AuthSystem)
    case sessionExpired(AuthSystem)
    case network(String)
    case http(status: Int, message: String?)
    case decoding(String)
    case invalidData(String)
    public var userMessage: String { get }   // 给 UI 显示的中文文案
}

// ── GxuNetworking ──
public struct DataEnvelope<T: Decodable & Sendable>: Decodable, Sendable { public let data: T }

/// 自建后端客户端。自动带上教务 Cookie；遇到 401 或会话失效时，用 Keychain 里的账号自动重新登录一次后重试。
public protocol BackendAPI: Sendable {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T
}
// 便捷方法：getData(...) 直接解出 DataEnvelope<T>.data

// ── GxuAuth ──
public enum AuthState: Sendable, Equatable { case noAccount, signedOut, authenticated }

@MainActor @Observable
public final class AccountCenter {
    public private(set) var states: [AuthSystem: AuthState]
    public private(set) var studentId: String?          // 当前教务账号学号，用于数据隔离
    public func login(_ system: AuthSystem, username: String, password: String) async throws
    public func logout(_ system: AuthSystem) async
    public func ensureAuthenticated(_ system: AuthSystem) async throws   // 失败时抛 GxuError
}

// ── GxuStorage ──
public struct FeatureMigrations: Sendable {
    public let feature: String                                   // 迁移 ID 的前缀，例如 "schedule"
    public let register: @Sendable (inout DatabaseMigrator) -> Void
}
public final class AppDatabase: Sendable {
    public let writer: any DatabaseWriter                        // GRDB
    public static func open(features: [FeatureMigrations]) throws -> AppDatabase
    public static func inMemory(features: [FeatureMigrations]) throws -> AppDatabase   // 测试用
}
public protocol SharedStore: Sendable {                          // App Group KV，App 和小组件共用
    func value<T: Codable & Sendable>(_ key: SharedKey<T>) -> T?
    func set<T: Codable & Sendable>(_ value: T?, for key: SharedKey<T>)
}
public struct SharedKey<T>: Sendable { public let name: String }

// ── 依赖注入（App/Composition 组装，用 SwiftUI Environment 下发）──
public struct AppServices: Sendable {
    public let backend: any BackendAPI
    public let database: AppDatabase
    public let shared: any SharedStore
    public let accounts: AccountCenter      // 只能在 MainActor 上访问
}
extension EnvironmentValues { @Entry public var services: AppServices = .preview }

// ── GxuTestSupport ──
public final class MockBackendAPI: BackendAPI  // 按 "METHOD path" 返回预设的 JSON 或错误
public func loadFixture(_ name: String, bundle: Bundle) throws -> Data
extension AppServices { public static var preview: AppServices }  // 内存数据库 + Mock 后端
```

迁移 ID 必须带 feature 前缀，例如 `schedule.v1.createCourses`。所有带用户数据的表都要有 `studentId` 列。

## 4. 协作规则

### 4.1 分支与 worktree（用户执行一次）

```bash
cd ~/Project/gxu_tool_app
git switch -c ios-native main
git add docs/ios-migration && git commit -m "docs: iOS 原生迁移方案"
git switch main
git worktree add ../gxu_ios_a -b ios/a-platform        ios-native
git worktree add ../gxu_ios_b -b ios/b-design-schedule ios-native
git worktree add ../gxu_ios_c -b ios/c-features        ios-native
brew install xcodegen
# 可选：在主 checkout 里执行 pnpm install，agent 就能读 node_modules/gxu-tool-adapters 里的类型定义
```

- `ios-native` 是集成分支，**不在任何 worktree 里 checkout**。
- 发布流程（只允许快进）：
  ```bash
  git rebase ios-native            # 先同步最新集成分支
  ios-native/scripts/build.sh && ios-native/scripts/test.sh
  git fetch . HEAD:ios-native      # 快进更新集成分支；失败说明有人先发布了，重新 rebase
  ```
- 每完成一个**能构建通过**的小步就发布一次，不要攒大包。
- 不要 `git push` 到远程，也不要动 `main` 分支。合并到 GitLab 由用户决定。

### 4.2 验证标准

- `scripts/build.sh`：`xcodegen generate` 后用 `xcodebuild` 构建 App 和 Widget scheme，目标是 iOS 模拟器。模拟器选择规则见 `scripts/_env.sh`：优先最新的 "iPhone NN Pro"，其次最新的普通 "iPhone NN"，排除 Duo / Fold / Flip / mini / Air 等特殊机型；可用 `SIM_ID=<udid>` 覆盖。构建使用 ad-hoc 签名（`CODE_SIGN_IDENTITY="-"`，见 §5.1 (e)）。
- `scripts/run-e2e.sh`：构建、安装、用 `.secrets/account.env` 的测试账号自动登录（仅 DEBUG，经 `SIMCTL_CHILD_GXU_TEST_USER/PASS` 传入）并截图。
- `scripts/test.sh`：运行所有 package 的测试。
- 有 UI 改动时：在模拟器里启动 App，用 `xcrun simctl io booted screenshot` 截图并**自己看一遍**，分别检查浅色和深色模式。截图放到 `ios-native/.screens/`（已 gitignore）。
- 不确定的接口字段：写 `// TODO(verify): ...`，并记在自己的 status 文件里。

### 4.3 状态汇报

每个 agent 维护 `docs/ios-migration/status/agent-<x>.md`，记录：当前 Phase、已完成、进行中、阻塞项、给其他 agent 的通知、TODO(verify) 列表。每次发布前更新。

### 4.4 Fixture（真实数据）

- 用户把测试账号放到 `ios-native/.secrets/account.env`（已 gitignore，内容是 `JW_USER=...`、`JW_PASS=...`）。
- A 提供 `scripts/capture-fixtures.sh`：登录后端，把各接口的原始响应保存到 `ios-native/Fixtures/raw/`（已 gitignore）。
- 脱敏后的共享数据由 A 用 `scripts/sanitize-fixtures.py` 生成，放在 `ios-native/Fixtures/sanitized/`（含 README，说明各文件对应的接口和参数），可直接提交。各 feature 的所有者按需把其中的文件复制到自己 package 的 `Tests/.../Fixtures/` 里；需要 A 没覆盖的接口，写到 COORDINATION 的 A 小节。
- 拿不到真实数据时，根据 RN 的 TS 类型和 Zod schema 手写 fixture，并标注 TODO(verify)。

## 5. 分阶段计划

### Phase 0：脚手架（只有 A 做，目标 1 小时内完成；B 和 C 同时读 RN 源码、写 spec）

A：搭好 `ios-native/` 骨架、`project.yml`、§2 里所有 package 的空壳（含 Package.swift，B/C 的 package 只建最小占位文件，之后归各自所有者）、§3 契约（可以先是最简实现）、`GxuTestSupport`、`build.sh`/`test.sh`、`.gitignore`、`COORDINATION.md` 模板、三个 status 文件。App 能启动并显示一个空的三标签 TabView。commit 信息必须包含 `[bootstrap]`，然后按 §4.1 发布。

B、C：在 bootstrap 发布之前，先读 RN 源码，把自己 Phase 1 功能的行为规格（数据来源、字段、边界情况、页面状态）写进 status 文件。用 `git log ios-native --oneline --grep bootstrap` 检查 bootstrap 是否已发布，发布后 rebase 再开始写代码。

### Phase 1：基础设施 + 最小可用版本（登录 → 课表 → 考试 → 成绩）

| Agent | 交付内容 |
|---|---|
| A | `GxuNetworking`：后端客户端、共享 Cookie、ATS 配置、错误映射、自动重新登录<br>`GxuAuth`：教务登录（`POST /jw/login`，从 Set-Cookie 里取 JSESSIONID 和 route）、Keychain 账号存储、`AccountCenter`<br>`GxuStorage`：GRDB + App Group、`SharedStore`<br>`capture-fixtures.sh`<br>FeatureAccount：设置 → 教务账号的登录页 |
| B | `GxuDesign` v1：主题（含用户自定义主题色）、玻璃封装（`GlassButton`、`GlassGroup`、`.gxuGlass()`）、`ContentCard`、加载/空/错误状态视图，写 `README.md` 说明用法和规则<br>Shell：三个 Tab（课表 / 工具箱 / 设置），工具箱网格 `ToolboxCatalog` 预先列出全部功能并标"即将上线"，设置首页骨架<br>ScheduleKit：课表模型、`GET /jw/schedule/personal`、学期开始日 `GET /jw/profile/startDay`、周次计算、下一节课计算、GRDB 缓存（先显示本地，再后台刷新）<br>ScheduleUI：周课表网格、玻璃周次切换器、"回到本周"按钮、课程详情 sheet |
| C | FeatureExam：考试信息 `GET /jw/exam`（按学号+学期缓存，显示倒计时）、成绩 `GET /jw/score`（**缓存加上 studentId**）、平时分 `GET /jw/score/usual`、GPA 计算器（逻辑移植自 `src/hooks/useGpa.ts`、`GPAcalculator.tsx`），并写单元测试<br>工具箱里对应的入口 |

**阶段验收**：真机或模拟器上能登录教务 → 看到真实课表 → 考试信息 → 成绩/GPA；构建和测试全部通过。

### 5.1 跨阶段约定（2026-11-05，用户已同意）

- **(a) ExamKit / ExamUI 拆分**：Phase 2 开始时，C 把 `FeatureExam` 拆成 `ExamKit`（不依赖界面，B 的首页和课表叠加要用）和 `ExamUI` 两个 product，沿用 `FeatureSchedule` 的做法。拆分时更新 `project.yml`（向 A 提请求）和 `FeatureRegistry`。
- **(b) 节假日和调课数据**：节假日和调课数据（`data.json`）的获取和模型由 B 放进 `ScheduleKit`；C 的节假日和调课页面读取它，不自己再请求。
- **(c) 脱敏共享数据**：放在 `ios-native/Fixtures/sanitized/`（见 §4.4）。
- **(d) 学期参数**：后端 GET 接口（`/jw/schedule/personal`、`/jw/exam`、`/jw/score`）**只接受逻辑学期 1 / 2**。2026-11-05 用真实后端验证：`term=3`（小学期）、`term=12`、`term=16` 一律返回 HTTP 400 `不支持的学期参数`。因此 feature **不能用 term=3 查询**；`AcademicTerm.isBackendQueryable` 为 false 时，UI 不要发请求（隐藏该学期或提示"暂不支持"）。`AcademicTerm.term == 3` 仍可用于展示。
- **(e) 小组件前置条件（已验证）**：未签名构建（`CODE_SIGNING_ALLOWED=NO`）下 Keychain 报 -34018、拿不到 App Group 容器。改用 ad-hoc 签名（`CODE_SIGN_IDENTITY="-"`，entitlements 由 `*-Simulated.xcent` 写进二进制）后，**App 能拿到 App Group 容器，Keychain 读写正常**，所以**模拟器开发不需要真实 Team ID**（`project.yml` 里 `DEVELOPMENT_TEAM` 保持占位符即可）。小组件扩展用同一个 `group.com.gxutool.ios`，entitlements 与 App 相同；扩展在运行时是否读到同一个容器，还要 C 在 Phase 2 做小组件时实测（在 Widget 里写入、在 App 里读取 SharedStore）。真机运行和 Keychain access group（`$(AppIdentifierPrefix)`）需要真实 Team ID，届时由用户填写。

- **(f) 一次性所有权例外（用户已同意，2026-11-05）**：小组件 / Live Activity / App Intents 这一批，由 C 直接发布 `project.yml`、`App/GxuToolApp.swift`、Info.plist 和 `App/Composition/IntentsPackage.swift` 的相关改动（含 `ClassWidgetKit`、`ToolboxIntents`、`NSSupportsLiveActivities`、`WidgetBridge`）。**仅此一批**，之后恢复 §2 的所有权。C 发布这批之前，A 不改这些文件里相关的部分。
- **(g) 小组件验证**：设计审查用 `ImageRenderer` 渲染的截图；§5.1 (e) 的"扩展是否读到同一个 App Group 容器"用 XCUITest 限时 30 分钟实测，做不出就留到真机（需要真实 Team ID）。这台机器没有 Simulator.app，无法手动操作。
- **(h) iOS 18 降级走查**：本机安装 iOS 18 模拟器 runtime 和一台专用模拟器，用 `SIM_ID` 跑 `run-e2e-ui.sh`，对比 iOS 27 与 iOS 18 的关键页面（课表、工具箱、考试、成绩、GPA、设置），截图放 `ios-native/.screens/ios18-*/`；问题按所有权写进 B、C 的请求区。磁盘空间不足时不安装，写进 A 的 status。
- **工具箱**：`空教室` 不在附录 A 和 RN 的 `src` 里，用户决定删除，由 B 执行。
- **节假日数据**：远程 `data.json` 没有 `holidays`，内置备份只到 2027 年元旦；更新方式待用户决定（见 §7）。

### Phase 2：系统集成 + 次要功能

| Agent | 交付内容 |
|---|---|
| A | CA 统一认证（参考 `src/js/auth/auth.ts`、`src/core/auth/unified/`，包含 PEC 和 xlzxms 的 SSO 会话）；考勤认证（token 走后端 `/attendance/*`）；OA token 客户端；`WebViewScreen`（`WKWebView` + Cookie 同步 + 弹窗推入新页面）；版本检查（iOS 只提示跳转 App Store/TestFlight，没有 OTA）；反馈 + 埋点；个人信息；设置里的 CA 和考勤账号页 |
| B | 首页/今日视图 + `tabViewBottomAccessory` 显示"下一节课"；手动编辑课表 / 自定义课程；冲突课程；课程和考试显示项设置；偏好/主题设置；班级课表查询、全校课表；导出/分享课表图片（`ImageRenderer` + `ShareLink`） |
| C | Widget extension：主屏小/中/大尺寸 + 锁屏 accessory，时间线在每节课的开始和结束各放一个条目；**Live Activity / 灵动岛**显示当前课或下一节课；App Intents（"今天/明天有什么课"）；已选课程、选课策略、节假日、调课通知；考勤界面（A 的考勤认证交付前先用 Mock） |

### Phase 3：长尾功能 + 打磨 + 上架

| Agent | 交付内容 |
|---|---|
| A | OA 文件（列表、详情、搜索、预览）、问卷 wjxt；隐私清单、ATS 复查、App 图标；`scripts/archive.sh`（打包上传 TestFlight）；错误日志 |
| B | 实践课（物理实验 PEC / 工程训练 xlzxms，依赖 A 的 CA 认证）、地图/教学楼/楼层图、校园网充值入口（WebView）；**全局视觉打磨**（玻璃用法一致性、动画、Dynamic Type、VoiceOver、深色模式） |
| C | 教学评价（总览、详情、评语、模板，模板存 GRDB，修正 RN 两套存储并存的问题）、教师信息查询；关键流程的 UI 测试；对照附录 A 逐项验收 |

## 6. Liquid Glass 设计规范（B 负责落地，所有人遵守）

**原则：RN 只用来确定"功能"，不用来确定"界面"。**（用户确认，2026-11-05）

- **需要和 RN 对齐的**：显示哪些数据、能做哪些操作、计算规则、状态（空、加载、错误、离线）、边界情况。
- **不需要对齐、也不要参考的**：布局、尺寸、颜色、字号、图标、文案的排版、交互形式（例如 RN 用 Modal 的地方，iOS 可以用 sheet、Menu、inline 展开或 contextMenu）。
- 界面按 Apple HIG 和 Liquid Glass 重新设计，参考系统自带 App（日历、提醒事项、天气、健康）的质感。同一个功能如果有更符合 iOS 习惯的做法，就用那种做法。
- 规格文档（status 文件等）里已经写进去的 RN 界面数值（行高、圆角、行数、前缀符号等）一律当作"仅供参考"，不是需求。

以下是具体的 Liquid Glass 规则：


1. **玻璃只用在导航层和浮动控件上**：标签栏、工具栏、浮动按钮、sheet、底部附件栏。**内容不用玻璃**：课程块、成绩列表、卡片正文。
2. 玻璃上不要再叠玻璃。多个相邻的玻璃控件放在 `GlassGroup`（内部是 `GlassEffectContainer`）里，让它们能合并和变形。
3. 系统 `TabView`、`NavigationStack` 工具栏和 sheet 会自动变成玻璃，**不要**给它们设置背景色或 `toolbarBackground`。
4. feature 代码里**禁止直接写** `.glassEffect`、`.buttonStyle(.glass)` 等，只能用 GxuDesign 的封装（统一降级逻辑，统一视觉）。
5. 颜色：用户主题色只作为强调色（`tint`）；课程色块用 GxuDesign 提供的调色板，同时适配浅色和深色模式。
6. 优先用系统控件（`List`、`Form`、`Picker`、`DatePicker`、`Menu`、`.sheet` + detents、`.contextMenu`、`.swipeActions`、`.refreshable`、`.searchable`）。
7. 图标只用 SF Symbols；文字用系统字体样式（`.headline`、`.body` 等），以支持 Dynamic Type。

## 7. 待用户决定 / 风险

- [x] 最低系统版本：**iOS 18**（已确定，GxuDesign 保留降级逻辑）。
- [ ] Bundle ID、Team ID、App 名称和图标（App Store 审核时，使用"广西大学"名称和校徽可能被问到知识产权问题）。
- [ ] 提供测试账号（`.secrets/account.env`）：教务账号已提供；**还缺统一认证 `CA_USER` / `CA_PASS`**（CA、PEC、工程训练中心的真实验证），以及一个考勤系统账号（完整登录需要人工看验证码）。
- [ ] `version.json`（`https://file.unde.site/GxuToolApp/version.json`）增加 `ios` 通道，iOS 版本检查才会有提示；格式见 COORDINATION「个人信息 / 反馈 / 埋点 / 版本检查 / WebView 容器已就绪」。
- [ ] 后端 `GET /feedback/{userId}` 对所有请求返回 401 "看板：未登录或登录已过期"（2026-11-05 真实验证，带有效教务 Cookie 也一样），iOS 的"我的反馈"无法查看；需要后端修复。
- [ ] 节假日数据：远程 `data.json` 没有 `holidays`，内置备份只到 2027 年元旦，更新方式待决定。
- [ ] 后端上 HTTPS；确认 iOS 也走后端代理时，后端的限流和稳定性够用。
- iOS 没有 OTA，修 bug 要走审核；TestFlight 可以作为测试通道。
- Android 和 iOS 两端要各写一遍功能，所以新的教务功能应该**先做后端接口**，两端都只接后端。

## 附录 A：功能对照表（RN 路由 → 负责人 / 阶段）

| RN 路由 / 功能 | 负责人 | Phase |
|---|---|---|
| 首页 `HomeScreen`（UpdateCard、ScheduleCard）、`ScheduleEdit` | B | 1–2 |
| `courseScheduleQuery`、`ExportScheduleScreen` | B | 1–2 |
| `classCourseSchedule`、`FullCourseScreen` | B | 2 |
| `phyExpScreen`、`engTrainingScheduleScreen` | B | 3 |
| `HolidayScreen` | C | 2 |
| `PositionListScreen`、`TeachBuildingListScreen`、`FloorListScreen`、`FloorMapScreen` | B | 3 |
| `EduRechargeScreen`（WebView） | B | 3 |
| `examInfo`、`examScore`、`gpaCalculator` | C | 1 |
| `SelfSelectedCourse`、`courseSelectionList`、`ElectiveStrategy` | C | 2 |
| `reschedulingNews`、`timeShiftScreen` | C | 2 |
| `AttendanceInfoQueryScreen` | C（认证由 A 负责） | 2 |
| `TeacherInfo` | C | 3 |
| `EvaluationOverview/Detail/Comment/Template` | C | 3 |
| `MainScreen`（OA 文件） | A | 3 |
| `WidgetPreviewScreen` → 由 WidgetKit 原生小组件代替 | C | 2 |
| 设置：`userPreferenceSetting`、`CourseItemDetailSetting`、`ExamItemDetailSetting` | B | 2 |
| 设置：`personalInfo`、`jwAccount`、`authAccount`、`attendanceSystemAccount`、`versionList` | A | 1–2 |
| `otaList` → iOS 不做 | — | — |
| `feedback`、`feedbackList`、`feedbackDetail` | A | 2 |
| `webViewScreen` | A | 2 |
| `TestPage` → 不做 | — | — |
