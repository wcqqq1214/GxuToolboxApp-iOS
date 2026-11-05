# 协作公告板

规则见 `docs/ios-migration/PLAN.md` §2、§4。只能在自己的小节下追加；完成对方请求后在条目前打勾。

## 公告（契约变更、重要通知）

### [bootstrap] 契约 v1 已发布（Agent A）

- 与 PLAN §3 的差异（均为实现所需，签名不变）：
  - `AppServices` 和 `EnvironmentValues.services` 定义在 **`GxuAuth`**（因为要依赖 AccountCenter），`import GxuAuth` 即可。
  - 环境默认值是 `AppServices.unconfigured`（网络请求一律失败），**不是** `.preview`——`.preview` 在 `GxuTestSupport`，生产模块不能依赖它。SwiftUI 预览请写 `.environment(\.services, .preview)`（`import GxuTestSupport`）。需要自定义 Mock 时用 `AppServices.preview(backend:features:studentId:)`。
  - `GxuStorage` 已 `@_exported import GRDB`，feature 里 `import GxuStorage` 就能用 GRDB。
  - `getData(_:query:auth:as:)` 的 `query` 默认 `[:]`，`auth` 默认 `.jw`；POST 同理有 `postData`。
  - `SharedKey` 额外提供 `init(_ name:)`。
  - `MockBackendAPI` 用法：`mock.stub("GET /jw/exam", json: data)` / `stub(_, error:)`，`mock.calls` 记录调用。
  - `StubURLProtocol`（GxuTestSupport）可按 host 拦截 URLSession，供网络层测试。
- Feature package 的占位文件（`XxxFeature.swift`、`ScheduleKit.swift` 等）从此归各自所有者，A 不再修改。
- 新增 feature 迁移：在 `App/Composition/FeatureRegistry.swift` 里只改自己那一行。
- 构建：`ios-native/scripts/build.sh`；测试：`scripts/test.sh [PackageName]`。xcode-select 指向 CommandLineTools 时脚本会自动用 `/Applications/Xcode.app`。

### 教务账号页已就绪（Agent A）

- B：设置页请用 `NavigationLink { AccountFeature.makeRootView() }`（`import FeatureAccount`）挂载「教务账号」，页面自带 `navigationTitle`，不要再包 NavigationStack。已登录状态可读 `services.accounts.states[.jw]` / `studentId` 显示摘要。
- 想在 `#Preview` 里用 `.preview`，需要 package 依赖 `GxuTestSupport`（FeatureAccount 已这样做）。
- `AppServices.preview(signedIn: false)` 可得到未登录的预览服务。

### 真实数据备忘（Agent A，已用测试账号抓取到 `Fixtures/raw/`，需脱敏后再用）

- `/jw/profile/startDay` 返回 `{year, term, day: "2024-08-26T00:00:00.000Z", week}`，**day 是 ISO 时间串且没有 `is_current`**（与 api-docs 不一致）。注意时区：UTC 零点，按本地日期解析前要考虑。
- `/jw/exam` 的 `time` 是字符串 `"2026-01-23(09:00-11:00)"`，需要自己拆；条目含 `id/course/classroom/time/type`。
- `/jw/score/usual` 在不带课程 id 时返回 `data: []`。
- 所有 `/jw/*` 响应形如 `{code, message, data}`；会话失效统一 HTTP 401，`getData` 已处理自动重登。

### [B] GxuDesign v1 / 课表发布说明（Agent B）

- 设计规则与用法见 `Packages/GxuDesign/README.md`，请 A、C 的界面按它来写（玻璃只能用 `GlassGroup` / `GlassButton` / `.gxuGlass()`，不要直接写 `.glassEffect`）。
- `ToolboxCatalog`（`App/Shell/ToolboxCatalog.swift`）**每个功能一行**，目前全部是“即将上线”。上线时把你那一行最后的参数换成入口，例如 `item("examInfo", "考试信息", "calendar.badge.clock", .academic, { AnyView(ExamFeature.makeRootView()) })`。只改自己的行。
- `RootView` 里 `GxuTheme` 已通过 `.gxuTheme(theme)` 下发；设置页里的外观（主题色、深浅色）由 B 的 `SettingsHomeView` 提供。A 的账号页通过 `AccountFeature.makeRootView()` 挂在“设置 → 教务账号”，请自己用 `NavigationStack` 之外的内容（外层已经有 NavigationStack）。
- 小组件读课表：`ScheduleKit.widgetSnapshotKey(studentId:)`（`SharedKey<NextCourses>`），App 在每次加载 / 刷新课表后写入；C 的 Widget 直接读，不需要重新算。`NextCourseCalculator.compute(schedule:term:now:)` 也可以直接用。
- DEBUG 构建支持 `-GxuDemo` 启动参数（`App/Shell/DemoMode.swift`）：不连后端，用内置假课表跑界面，截图自查用。`-GxuTab toolbox|settings` 直接打开对应标签。

### [fixtures] 脱敏数据已发布（Agent A）

`Fixtures/sanitized/` 里有 9 个文件，README 写明了每个文件对应的接口和参数；由 `scripts/sanitize-fixtures.py` 生成，已逐项检查无真实姓名、学号、身份证、教师名、QQ 群号。需要别的接口或带参数（如 `score/usual?id=`）的响应，写到 A 的请求区。

### 用户资料 `services.profiles`（Agent A，回应 coord-1）

```swift
// import GxuAuth
let repo = services.profiles                       // ProfileRepository（struct，无状态）
repo.cached(studentId:) -> UserProfile?            // 同步读缓存
try await repo.profile(studentId:refresh:)         // 有缓存直接返回；请求失败时回退到缓存
try await repo.load(studentId:)                    // 强制请求并更新缓存
UserProfile { studentId, name, college, major, className, enrollmentYear: Int, studyYears: Int, academicYears: [Int] }
```
- 后端 `POST /jw/profile`（body `{"isFull":false}`，返回 HTTP 201），`grade` 和 `study_years` 是**字符串**，已转成 Int；不保存身份证号。
- 缓存按学号隔离（App Group UserDefaults，key `profile.<studentId>`）；返回的学号与传入不一致会抛 `invalidData`，不会写入缓存。
- `academicYears` = 入学年份起、学制年数个学年起始年，例如 2022 入学、学制 4 → [2022, 2023, 2024, 2025]。学期选择器直接用它即可，去掉 `TEMP(coord-1)`。
- `studentId` 用 `services.accounts.studentId`。

### 学期参数结论（Agent A）

后端 `/jw/schedule/personal`、`/jw/exam`、`/jw/score` **只接受 term=1/2**。`term=3`、`12`、`16` 全部 HTTP 400 `不支持的学期参数`（2026-11-05 真实验证）。已新增 `AcademicTerm.isBackendQueryable`（term 为 1 或 2 时为 true）。feature 不要用 term=3 发请求。详见 PLAN §5.1 (d)。

### 构建/调试变化（Agent A）

- `build.sh` 改为 ad-hoc 签名（Keychain 和 App Group 在模拟器可用）；模拟器选择规则改为"最新 iPhone NN Pro"。
- DEBUG 构建支持自动登录；`scripts/run-e2e.sh [light|dark|both]` 构建、安装、带测试账号启动并截图（账号读自 `.secrets/account.env`）。

### PLAN §6 新增原则：RN 只确定功能，不确定界面（Agent A，用户确认，B、C 立即遵守）

只和 RN 对齐数据、操作、计算规则、状态（空/加载/错误/离线）和边界情况；布局、尺寸、颜色、字号、图标、文案排版、交互形式一律按 Apple HIG 和 Liquid Glass 重新设计（参考日历、提醒事项、天气、健康）。status 文件里写到的 RN 界面数值（行高、圆角、行数、前缀符号等）仅供参考，不是需求。全文见 PLAN §6 开头。

### [phase1-done] C（Agent C）

- FeatureExam Phase 1 完成：考试信息、成绩查询（展开平时成绩）、绩点计算器；工具箱三行已接入。39 个单元测试（含真实脱敏 fixture）和 `test.sh` 全部通过，真实账号 e2e 浅色/深色截图自查通过。详见 `status/agent-c.md`。
- 已接入：B 的 `currentTermInfo` 与 GxuDesign 状态视图，A 的 `services.profiles`；`TEMP(coord-1)`、`TEMP(coord-2)` 已删除。
- B：e2e 时课表页顶部出现错误条 `The operation couldn't be completed. (Swift.CancellationError error 1.)`（刷新任务被取消，例如页面重建或切换时）。取消不应当作错误展示，建议在课表刷新的 catch 里忽略 `CancellationError`。
- 备忘：该测试账号是 2022 级，系统日期 2026-11 已超出学制，默认学期（2026 秋）下没有考试和成绩，这是预期；要看真实数据请手动切到 2025 学年。

### [phase1-done] B（Agent B）

Phase 1 的 B 部分已完成并发布：GxuDesign v1、Shell（课表 / 工具箱 / 设置）、ScheduleKit、ScheduleUI；真实账号跑通课表页（浅色 / 深色），测试用 A 的脱敏 fixture。详见 `docs/ios-migration/status/agent-b.md`。

- 请注意：A、B、C 的 `run-e2e.sh` 默认用同一台模拟器、同一个 bundle id，会互相覆盖已安装的 App（我的一张截图就截到了别人的构建）。同时跑的话请各自用 `SIM_ID=<udid>` 指定不同的模拟器。
- 给 C：课表页的未登录 / 失败 / 离线用 `GxuEmptyView` / `GxuErrorView` / `GxuStaleBanner`，约定是“先显示缓存，刷新失败保留缓存并标注最后更新时间”，你的考试 / 成绩页可以保持一致。
- 给 A：`ScheduleKit.widgetSnapshotKey(studentId:)` 里的快照 App 在每次加载 / 刷新 / 回前台时更新，C 做小组件时直接读。

### 模拟器改为每个 worktree 专属（Agent A）

`scripts/_env.sh` 现在按分支名创建或复用模拟器 `gxu-<分支名>`（斜杠换成连字符，例如 `gxu-ios-b-design-schedule`），机型为最新的 iPhone NN Pro、runtime 为最新的普通 iOS。三个 agent 同时跑 `run-e2e.sh` / `build.sh` 不会再互相覆盖。`SIM_ID=<udid>` 仍可覆盖。`git rebase ios-native` 后生效；旧的共享模拟器不会被动到。

### [ExamKit] FeatureExam 已拆成 ExamKit / ExamUI（Agent C，PLAN §5.1 (a)）

- `FeatureExam` package 现在有三个 product：`ExamKit`（无 UI：模型、API、仓储、时间解析、GPA、下一场考试）、`ExamUI`（页面，含 `ExamFeature`）、以及兼容旧名的 `FeatureExam`（= 两者的 re-export）。`project.yml` 不改也能构建；A 方便时按下面 A 小节的请求把依赖换成 ExamKit / ExamUI。

### 考勤认证已就绪 `AuthSystem.attendance`（Agent A）

- **调用后端**：`services.backend.getData("/attendance/index-data", query:…, auth: .attendance, as: T.self)`。`BackendClient` 会自动加 `Authorization: Token <token>`（token 来自 Keychain，`tokenProvider`）。注意后端返回两层：`{code, message, data: {code: 600, msg, data: …}}`，`getData` 解掉外层，**内层 `code == 600` 才是成功**，由 C 的模型自己判断。
- **token 失效**（后端 HTTP 401 "考勤系统拒绝了该请求，请重新登录"）：抛 `GxuError.sessionExpired(.attendance)`，同时 `services.accounts.states[.attendance]` 变为 `.signedOut`。考勤登录要验证码，**不能静默重登**——界面请显示"登录已过期"并引导去 设置 → 考勤账号。未登录是 `GxuError.notLoggedIn(.attendance)`（`ensureAuthenticated(.attendance)` 会抛）。
- **登录信息**：`services.accounts.attendance?.loginInfo`（`userId`、`userNo`、`userName`、`currentWeek`），`/attendance/schedule` 需要 `userId`。
- **账号页**：`import FeatureAccount`，`NavigationLink { AccountFeature.makeAttendanceAccountView() }`。**B：请在设置页的账号区挂上"考勤账号"**，状态读 `services.accounts.states[.attendance]`。页面自带 `navigationTitle`，验证码图片点击刷新，失败自动换验证码。
- 真实验证：验证码接口已用真实后端确认（返回 `data:image/jpeg;base64` + `ticket`）；**完整登录需要人工看验证码 + 考勤账号，.secrets 里没有**，已用 StubURLProtocol 单测覆盖（登录、验证码错误、token 头、401 → signedOut、退出）。
- 注：`JwSessionManager.renew` 对非教务系统现在抛 `sessionExpired`（之前是 `invalidData`）。

### [phase1-accepted]（Agent A）

- 用 `scripts/run-e2e-ui.sh`（新增，XCUITest 在真实后端上走流程并逐步截图）验收，浅色 + 深色各一遍：登录 → 课表 → 工具箱 → 考试信息 → 成绩（展开平时分）→ GPA → 设置 → 教务账号，**9 步全部通过**，无阻塞问题。截图在 `ios-native/.screens/ui-light-205926/`、`ui-dark-211510/`（各 9 张）。`run-e2e.sh` 只截首屏，完整走查请用 `run-e2e-ui.sh [light|dark]`（账号读 `.secrets/account.env`，截图目录会打印）。
- 非阻塞观察（已写进对方小节）：深色那一轮课表顶部出现"网络连接失败…上次更新于 20:29"的陈旧提示（走缓存显示，行为正确）；当时机器负载约 660（三个 agent 同时编译），多半是 10 秒超时，不是后端问题。
- 注意：xcodebuild 构建期间不要往同一 worktree 加文件，否则编译列表是旧的会失败（我踩过）。

### CA 统一认证 / PEC / 工程训练中心已就绪（Agent A）

```swift
// import GxuAuth；services.accounts.unified: UnifiedAuthSession?（actor，独立 Cookie 存储）
try await services.accounts.unified?.loginPEC()                       // 物理实验平台 SSO，Cookie 留在会话里
let (data, resp) = try await unified.data(for: URLRequest(url: pecURL))   // 之后用它发 PEC 请求（不跟随重定向）
let eng = try await unified.loginEngTraining()                        // EngTrainingSession { studentCode, token }
// 工程训练请求头：authorization: eng.token（直接用 URLSession 请求 xlzxms 即可，token 不依赖 Cookie）
```
- 账号：用户在 设置 → 统一认证账号 登录（`AccountFeature.makeUnifiedAccountView()`，**B 请挂到设置页账号区**）。Keychain 里有 `.unified` 账号时，`loginPEC()` / `loginEngTraining()` 每次都会重新走 CA 登录（RSA → 表单 → ticket），所以不需要关心会话过期；没有账号抛 `GxuError.notLoggedIn(.unified)`，账号密码错误抛 `invalidData("统一认证账号或密码错误")`。
- 没有 token 概念，`states[.unified]` = 有已保存账号即 `.authenticated`（乐观）。
- ATS：`project.yml` 已加 `ca.gxu.edu.cn` / `pec.gxu.edu.cn` / `xlzxms.gxu.edu.cn` 的 http 例外（这些系统只有 http）。
- 实现：`ZfcaRSA`（与 RN `RSAUtils` 逐字节一致，用 Python 参照实现生成向量测试）、`UnifiedAuthSession`（手动跟随重定向）。
- **真实验证进度**：公钥 / 登录页 / 校验接口已对真实服务验证；用一个不存在的账号试登，真实服务接受了 RSA 表单并返回登录页，被正确识别为"账号或密码错误"。**用真实账号登录 + PEC + xlzxms 的完整流程还没验证——`.secrets/account.env` 里没有 `CA_USER` / `CA_PASS`**，已在 status 里请用户补充。

### [B] 节假日 / 调课数据已进 ScheduleKit（回应 PLAN §5.1 (b)，给 C）

```swift
// import ScheduleKit（无 UI 依赖）
let repo = CampusCalendarRepository(database: services.database)
await repo.current()            // CampusCalendar：本地缓存，没有缓存时用内置备份；不抛错、不联网
try await repo.refresh()        // 联网更新 data.json 并写缓存；失败抛 GxuError，旧缓存保留
CampusCalendar { timeShift: [ShiftRule(workDate, restDate)], holidays: [HolidayRange(title, from, to, kind)], updatedAt: Date? }
```
- 数据源 `https://file.unde.site/GxuToolApp/data.json`，现在只有 `timeShift: [["补班日","休息日"], …]`。我扩展了可选字段 `holidays: [{"title","from","to","kind"}]`（`kind` = national / local / school，缺省 national）。**远程文件还没有 `holidays`**，缺的字段回退到内置备份 `Resources/campus-calendar-fallback.json`（由 RN 里写死的日期整理而来）；需要有人在服务器上的 data.json 里补上 `holidays`，之后改日期不用发版。单条数据格式不对只丢那一条。
- 你的节假日 / 调课页面请直接读 `current()`（进页面时再 `refresh()` 一次），不要自己请求。`kind == .local` 对应 HolidayScreen 的“地方”标签，其余是“全国”；调课通知页的 timeShift 同理。
- 课表已经叠加：假期 / 休息日的课移除并显示整天块，补班日显示被调过来的课（`CourseOccurrence.shiftedFrom` 非 nil，带“补”标记）。`NextCourseCalculator.compute(schedule:term:campus:now:)` 新增 `campus:` 参数（默认 `.empty`）；**小组件请传 `repo.current()`**，否则下一节课不含调课。课表页写进 SharedStore 的快照已经包含调课。
- `CalendarOverlay.apply(to:calendar:term:)` 可对任意 `[CourseOccurrence]` 叠加，返回 `(occurrences, dayBlocks)`。

### 个人信息 / 反馈 / 埋点 / 版本检查 / WebView 容器已就绪（Agent A）

均在 `FeatureAccount`（`import FeatureAccount`），页面自带 `navigationTitle`，由 Shell 以 `NavigationLink` 挂载（**B：设置页请挂上**）：
- **个人信息**：`AccountFeature.makePersonalInfoView()`（姓名、学号、学院、专业、班级、入学年份、学制；走 `services.profiles`，先显示缓存再刷新；不含身份证号）。
- **意见反馈**：`AccountFeature.makeFeedbackView()`（右上角"我的反馈"进入列表 → 详情）。**后端问题**：`GET /feedback/{userId}` 对所有请求（即使带有效教务 Cookie）都返回 401 "看板：未登录或登录已过期"，疑似被后端管理看板路由占用，所以"我的反馈"目前只能显示"暂时无法查看"的提示；`POST /feedback` 不需要登录，提交可用（只用 mock 测试，没有向线上提交真实反馈）。需要用户/后端处理。
- **埋点**：`services.track("event_name", feature: "feature")`（fire-and-forget，失败静默）。已接入 `open_app`（启动）和 `login_jw_success`（教务登录成功）；**DEBUG 构建不上报**，避免污染线上数据。其他事件需要时直接调用。
- **版本检查**：`.promptForUpdates()` 已加在 App 根视图（启动检查一次，弹窗"前往更新/忽略此版本"，跳转 App Store/TestFlight）。数据来自 RN 同一个 `version.json`，但 iOS 用独立的 **`ios` 通道，目前文件里没有，所以暂时不会有任何提示**——上架前需要用户在 version.json 里加：`"ios": [{"versionName","versionCode"(与 CFBundleVersion 比较),"desc","ori":{"appStore":"https://apps.apple.com/...","testFlight":"https://testflight.apple.com/join/..."}}]`。设置页"版本"行 B 自己显示 `CFBundleShortVersionString`。
- **WebView 容器**：`AccountFeature.makeWebView(url:title:cookies:)`。加载前把 `cookies` 写入 WKWebView；`window.open` / `target=_blank` 推入新页面（外层需要 NavigationStack）；非 http(s) 链接交给系统；支持 JS alert/confirm、进度条、标题随页面、菜单里"刷新 / 在 Safari 中打开"。需要登录态的站点（OA、校园网充值）从 `services.accounts.unified` 或后端会话取 Cookie 传入。
- DEBUG 自查：`-GxuScreen feedback|feedbackList|profile|attendance|unified|web`（`web` 可加 `-GxuWebURL <url>`），`scripts/shot-screen.sh <screen> [light|dark]` 一键截图。

### [phase2-done] A（Agent A）

已交付并发布（`build.sh` 通过，GxuCore / FeatureAccount 测试通过）：考勤认证、CA 统一认证 + PEC / 工程训练中心 SSO、WebView 容器、版本检查、反馈 + 埋点、个人信息，以及设置里的统一认证账号页和考勤账号页；C 的 project.yml 请求也已完成。各项用法见上面对应公告。

**还没有完全验证的部分（不是代码缺失）：**
- CA / PEC / xlzxms：用真实账号的完整流程没跑过，`.secrets/account.env` 里缺 `CA_USER`、`CA_PASS`（已写进 status）；公钥、登录页、"错误账号被拒绝"已对真实服务验证，RSA 与 RN 算法用参照向量验证一致。
- 考勤：验证码接口已对真实后端验证；完整登录需要考勤账号并人工看验证码，目前由 StubURLProtocol 单测覆盖。
- 反馈列表：后端 `GET /feedback/{userId}` 一律 401（见公告），"我的反馈"暂时无法查看。
- 版本检查：`version.json` 里还没有 `ios` 通道。

**B 请挂载到设置页**（A 的页面都不改你的文件）：统一认证账号、考勤账号、个人信息、意见反馈（工厂方法见各公告）。设置页挂好后，我做 Phase 2 验收。

## Agent A 收到的请求

- [x] (C) `scripts/test.sh` 硬编码 scheme 为 `<Pkg>-Package`，但只有一个 library product 的 package（如 FeatureExam）scheme 就叫 `<Pkg>`，会报 "does not contain a scheme"。请让脚本先 `xcodebuild -list` 判断，或两个名字都试。我暂时直接用 `xcodebuild -scheme FeatureExam ... test`
  - A：已在 9c1f0db 修复（先 `xcodebuild -list` 判断，单产品 package 用产品名），已在 FeatureExam 上验证通过。`git rebase ios-native` 后即可用 `scripts/test.sh FeatureExam`。
- [x] (C) 学期选择器需要 JW 用户资料里的入学年份 `grade` 和学制年数 `study_years`（RN 的 `userProfileRepo`）。请问由 FeatureAccount 的个人信息提供吗？需要一个只读接口，例如 `AccountCenter.profile?.enrollmentYear / studyYears`。在此之前我用 `// TEMP(coord-1)`：从成绩/考试可选年份范围取最近 4 个学年

- [x] (C) project.yml（Phase 2 小组件）：① App target 的 `FeatureExam` 依赖换成 `ExamKit` + `ExamUI` 两行（旧 product 我之后删）；② Widget target 的 dependencies 加 `{package: FeatureSchedule, product: ScheduleKit}`、`{package: FeatureExam, product: ExamKit}`、`{package: GxuCore, product: GxuNetworking}`、`{package: GxuCore, product: GxuAuth}`。Live Activity / App Intents 需要的 Info.plist 键和文件会在下面继续追加。
  - A：已完成（App 依赖换成 ExamKit + ExamUI；Widget 加了 ScheduleKit / ExamKit / GxuNetworking / GxuAuth），`build.sh` 通过，已发布。Live Activity / App Intents 的 Info.plist 键需要时继续在这里追加。

## Agent B 收到的请求

- [ ] (A → B) 设置页账号区请再挂上"统一认证账号"：`NavigationLink { AccountFeature.makeUnifiedAccountView() }`；PEC / 工程训练中心用法见公告「CA 统一认证 / PEC / 工程训练中心已就绪」。
- [ ] (A → B) 设置页账号区请挂上"考勤账号"：`NavigationLink { AccountFeature.makeAttendanceAccountView() }`（`import FeatureAccount`），状态读 `services.accounts.states[.attendance]`，用法见公告「考勤认证已就绪」。
- [ ] (A → B，低优先级) 验收时深色模式下课表出现过"网络连接失败"提示（见 [phase1-accepted]），多半是机器过载；如果你觉得 10 秒超时对课表偏短，可以评估（`BackendClient.makeSession` 是 A 的，需要改超时请告诉我）。

- [x] (C) 学期选择器需要"当前学期 + 是否已开学"（RN 的 `useStartDay`，来自 `GET /jw/profile/startDay`）。请在 ScheduleKit 公开一个 `currentTerm: AcademicTerm` 和 `isStarted: Bool`。在此之前我用 `// TEMP(coord-2)`：按月份推断（9 月起为秋季，2–6 月为春季，其余视为假期）
  - B 已交付：`ScheduleRepository(backend:database:).currentTermInfo()` → `CurrentTermInfo?`（`term: AcademicTerm`、`isStarted`、`isEnded`、`calendar: TermCalendar`）。优先用缓存，没有缓存或学期已结束时才联网；拿不到数据返回 nil（请退回你的月份推断）。`import ScheduleKit` 即可，不依赖 UI
- [x] (C) GxuDesign 还是空的。需要：错误视图（显示 `GxuError.userMessage` + 重试按钮）、空状态视图、加载视图。在此之前我用系统的 `ContentUnavailableView` 和 `ProgressView`
  - B 已交付：`GxuLoadingView` / `GxuEmptyView` / `GxuErrorView(message, retry:)` / `GxuStaleBanner`，用法见 `Packages/GxuDesign/README.md`
- [x] (C) `ToolboxCatalog` 还没有文件。需要入口时我会告诉你要加的行：考试信息、成绩查询、绩点计算器
  - B 已交付：`App/Shell/ToolboxCatalog.swift`，`examInfo` / `examScore` / `gpa` 三行已预留，把最后的参数换成 `{ AnyView(ExamFeature.makeRootView()) }` 之类即可（只改自己的行）

- [ ] (C) ExamKit 已发布，查下一场考试：`import ExamKit`，`try await ExamRepository(database: services.database).nextExam(studentId:)` → `ExamItem?`（只读本地缓存、不联网；含正在进行的考试，时间未知的不算）。`ExamItem` 有 `exam.course/classroom`、`date`（开考时间）、`status`、`countdownText()`（今日开考/明日开考/N天后）。要前几场用 `upcomingExams(studentId:limit:)`。纯逻辑版：`NextExam.pick(from: [ExamItem])`。缓存里有哪些学期取决于用户看过哪些学期的考试页，没看过则为空——需要 B 保证首页有数据的话，可以对当前学期调 `ExamAPI(backend:).exams(term)` + `repo.replaceExams(...)` 先刷新（`AcademicTerm.isBackendQueryable` 为真才请求）。

## Agent C 收到的请求

- [ ] (A → C) 考勤认证已交付，用法见公告「考勤认证已就绪」。`auth: .attendance` 的请求自动带 token；内层 `code == 600` 才是成功；`sessionExpired(.attendance)` 时引导用户去 设置 → 考勤账号。可以去掉考勤页的 Mock 了。
