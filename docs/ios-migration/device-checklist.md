# 真机验证清单

模拟器验证不了的东西。每项写了**步骤、预期结果、谁来操作**。从仓库根目录运行 `scripts/run-device.sh --check` 确认前置条件。

**操作人说明：** 「用户」= 需要有手机、账号或校园网的人；「A / B / C」= 对应 agent 在用户把设备连好、`run-device.sh` 能跑通之后可以代为执行的步骤（agent 不能碰手机屏幕，需要看屏幕的步骤只能由用户做）。

## 0. 前置条件（用户提供）

| 需要什么 | 说明 |
|---|---|
| 付费的 Apple Developer Program 账号和 **Team ID** | App Group、Keychain 共享、Live Activities 都需要，免费个人账号做不到。Team ID 写进环境变量 `DEVELOPMENT_TEAM` 或 `.secrets/archive.env`（`DEVELOPMENT_TEAM=XXXXXXXXXX`），**不要提交进 git** |
| 一台 iPhone（iOS 18 或更新，建议再有一台 iOS 18.x 的） | 数据线连接、解锁、信任此电脑；设置 → 隐私与安全性 → 开发者模式打开；Xcode 里登录了 Apple ID |
| 能在手机上连校园网（或校园 VPN） | CA、PEC、金工实训、OA、wjxt 只有校内网络才能访问 |
| 账号 | 统一认证 `CA_USER` / `CA_PASS`；OA 账号（与问卷系统共用）；考勤系统账号；教务测试账号（已有）。放进 `.secrets/account.env`（不入库）；真机上由用户自己在 App 里登录，脚本不会传递密码 |

**Team ID 怎么填：** `cp .secrets/archive.env.example .secrets/archive.env`，把里面的 `XXXXXXXXXX` 改成你的 Team ID 就行（`.secrets/archive.env` 不会进 git；模板 `archive.env.example` 可以提交）。

**两种装法：**
- 手机连着电脑：`scripts/run-device.sh`（只有一台真机时自动选择；多台用 `--device <名称或UDID>`）。
- 想自己拿文件装：`scripts/run-device.sh --ipa`，导出 `build/export/GxuToolApp.ipa`，结束时会打印绝对路径和安装方式（Xcode 的 Devices and Simulators 窗口 / Apple Configurator / `devicectl`）。**手机必须是 development 描述文件里登记过 UDID 的设备**：先用数据线连一次电脑让 Xcode 自动登记，或在 developer.apple.com → Devices 里手动加 UDID。

首次运行 Xcode 会自动注册 App ID、App Group `group.com.gxutool.ios`，这需要账号有权限。Bundle ID 目前固定为 `com.gxutool.ios`，如果提示已被别的团队占用，要先让开发者把它改成可配置的。

## 0.5 只有免费 Apple 账号：`--personal` 模式

`scripts/run-device.sh --personal`：
- **Team ID 自动取**：从 Xcode 登录的账号（优先免费个人团队）或钥匙串里的 Apple Development 证书取，不用手填；多个会列出（打码），用 `DEVELOPMENT_TEAM=<完整 ID>` 指定。取不到会提示怎么做。
- **Bundle ID 可改**：默认 `com.gxutool.ios`；被别的团队占用（Xcode 报 "cannot be registered … not available"）时，设 `BUNDLE_ID=com.<你的名字>.gxutool`（环境变量，或写进 `.secrets/archive.env`）。Widget 自动用 `<BUNDLE_ID>.widget`，App Group 用 `group.<BUNDLE_ID>`。
- **先按完整能力签名**（App Group + Keychain 共享），Xcode 说「个人团队不支持」才自动降级成没有这两项的 Debug 构建，并打印实际结论；降级只对这次构建生效，不改 `project.yml` 和正常构建。降级时 App 数据库和偏好存在 App 自己的容器里，小组件读不到 App 的数据（显示「未就绪」），App 本身不受影响。
- **7 天过期**：免费账号的描述文件 7 天后过期，过期后 App 打不开，**重新运行这条命令**重新安装。首次打开要在「设置 → 通用 → VPN 与设备管理」里信任开发者。
- 一台手机最多装 3 个免费账号签名的 App，每周能注册的 App ID 也有限制；换 `BUNDLE_ID` 会占用新的 App ID。

**`--personal` 下能验证 / 不能验证：**

| 项 | 能不能 | 说明 |
|---|---|---|
| 第 2 节 大字号、VoiceOver | ✅ | 不依赖账号类型 |
| 第 3 节 账号 / 校园网功能（CA、PEC、金工实训、考勤、OA、wjxt） | ✅ | 只要手机能连校园网、用户有账号 |
| 4.3 回前台刷新、4.4 断网缓存、4.6 登录过期自动重登 | ✅ | |
| 1.8 App Intents | ✅（App 内部的 intent） | 不依赖 App Group 时可用；读 App 数据的结果取决于是否降级 |
| 1.1–1.7 小组件、Live Activity（共享数据） | 看实际结论 | 个人团队支持 App Group 才能验证；降级时小组件只会显示「未就绪」 |
| 4.1 Keychain access group（App 和扩展共享） | 看实际结论 | 同上；降级时每个 target 用自己的 Keychain |
| 4.2 卸载重装后的 Keychain 行为 | ✅ | |
| 5.1 真实 iOS 18 | ✅（如果手机是 iOS 18） | 需要 iOS 18 的设备 |
| 5.3 TestFlight、`archive.sh` 上传、`--ipa` 导出 | ❌ | 需要付费的 Apple Developer Program 账号 |

## 1. 小组件、Live Activity、App Intents（PLAN §5.1 (e)）

| # | 步骤 | 预期结果 | 谁 |
|---|---|---|---|
| 1.1 | 打开 App 并登录教务账号，等课表加载完；回到主屏，长按 → 添加小组件 →「西大工具箱」，依次添加小 / 中 / 大三个尺寸 | 三个尺寸都能添加，显示今天正在上的课和接下来的课，和 App 里「今天」页一致 | 用户 |
| 1.2 | 锁屏上添加「矩形」和「行内」小组件 | 显示下一节课（课名、时间、教室）；行内一行不被截断 | 用户 |
| 1.3 | **App Group 共享（§5.1 (e)）**：在 App 里下拉刷新课表，然后回主屏看小组件 | 小组件内容在几秒到几分钟内与 App 一致，说明小组件读到了 App 写入的 `group.com.gxutool.ios` 数据。如果一直是空白 / 占位，说明扩展没读到同一个容器 | 用户（看屏幕）；A 可以在设备日志里查 `Widget` 读 App Group 的结果 |
| 1.4 | **切换账号**：设置 → 教务账号 → 退出登录，再用另一个学号登录；回主屏看小组件 | 小组件不再显示上一个账号的课（空白 / 提示去登录，随后变成新账号的课），**不能出现旧账号的数据** | 用户（需要第二个教务账号） |
| 1.5 | 一天中经过一节课的开始和结束时间前后各几分钟观察小组件 | 在每节课开始和结束的时刻小组件切换到对应条目（时间线条目） | 用户 |
| 1.6 | **Live Activity / 灵动岛**：在一节课开始前（或按设计的提前量）打开 App，观察锁屏和灵动岛 | 出现「当前课 / 下一节课」的实时活动：倒计时和进度条随时间变化；长按灵动岛展开样式正常；课结束后活动消失 | 用户 |
| 1.7 | 在 Live Activity 显示时锁屏、回主屏、杀掉 App | 活动继续按时间更新（倒计时由系统驱动），不显示错误的时间 | 用户 |
| 1.8 | **App Intents**：打开「快捷指令」App，新建快捷指令，搜索「西大工具箱」，运行「今天的课」「明天的课」「下一场考试」；再对 Siri 说对应的话 | 返回正确的文字结果（和 App 里一致）；没有数据时说明原因而不是崩溃 | 用户 |

## 2. 大字号（Dynamic Type）和 VoiceOver

| # | 步骤 | 预期结果 | 谁 |
|---|---|---|---|
| 2.1 | 设置 → 辅助功能 → 显示与文字大小 → 更大字体，拖到最大（并打开「更大的辅助功能字体」）；依次看 今天 / 课表 / 工具箱 / 考试 / 成绩 / 设置 / 账号页 / OA 文件 | 文字不被裁切、不重叠，列表和卡片自动变高；课表网格保持可读（周网格限制在 xLarge 以内是设计） | 用户 |
| 2.2 | 同上，再看浅色 / 深色模式各一遍 | 同上，颜色对比正常 | 用户 |
| 2.3 | 打开 VoiceOver（设置 → 辅助功能 → VoiceOver），在 今天 / 课表 / 工具箱 / 设置 里逐项滑动 | 每个控件读出有意义的名称；工具箱图标不重复朗读；课程块读出课名、时间、教室；假期色带有文案；楼层图有「双击放大」提示 | 用户 |
| 2.4 | VoiceOver 下完成：登录教务账号、查看成绩、展开平时分 | 全程可以只靠 VoiceOver 完成 | 用户 |

## 3. 需要账号或校园网的功能

| # | 步骤 | 预期结果 | 谁 |
|---|---|---|---|
| 3.1 | **CA 统一认证**：设置 → 统一认证账号 → 登录 | 登录成功；服务端明确拒绝时转述它的提示，需要验证码 / 被拒绝访问 / 服务异常时各说各的 | 用户。**✅ 已验证（2026-11-06，用 `.secrets` 里的真实账号，A 的 Swift 代码在模拟器上登录 + 校验接口通过；手机上的登录由用户再点一次确认）** |
| 3.2 | **PEC 物理实验课**：工具箱 → 实践课 → 物理实验课（需先登录统一认证，在校园网下） | 显示实验课列表；字段和 RN 一致（TODO(verify)：实际响应字段） | 用户；字段不一致写给 B |
| 3.3 | **金工实训**：工具箱 → 实践课 → 金工实训 | 显示金工实训课表；token 有效（xlzxms） | 用户 |
| 3.4 | **考勤**：设置 → 考勤账号 → 看验证码、输入账号密码和验证码登录；工具箱 → 考勤信息 | 登录成功；验证码错误时换一张并提示；考勤信息按学期显示；token 过期（可等一段时间或在别处登录挤掉）时提示重新登录 | 用户（要人工看验证码）；字段不一致写给 C |
| 3.5 | **OA 文件**：设置 → OA 账号登录；工具箱 → 学校文件 | 列表、按类型筛选、标题搜索、翻页、详情正文都正常；PDF / DOCX 附件能预览；校外网络时提示「OA 系统拒绝访问，可能需要连接校园网」 | 用户 |
| 3.6 | **wjxt 待阅文件**：OA 文件页右上角菜单 →「旧系统待阅文件」 | 显示待阅列表，点开能在 WebView 里看到文件；会话过期自动重登 | 用户 |
| 3.7 | 把 PEC / 工程训练中心的 CAS service 地址换成 https 试一下 | 如果能成功，可以去掉 `project.yml` 里 `pec.gxu.edu.cn` / `xlzxms.gxu.edu.cn` 的 http 例外（收紧 ATS） | A（拿到 3.2 / 3.3 的结果之后） |
| 3.8 | 地图导航：点一个地点的导航按钮；教学楼平面图：打开楼层图并缩放 | Apple 地图按全名搜到校内位置；楼层图加载并可双指缩放 | 用户 |

## 4. Keychain、后台刷新、回前台刷新

| # | 步骤 | 预期结果 | 谁 |
|---|---|---|---|
| 4.1 | **Keychain access group**：用真实 Team ID 装好后，登录教务账号；杀掉 App 再打开 | 保持登录（凭据读写正常，没有 `-34018` 之类的错误）。`GxuConfig.keychainAccessGroup` 此时返回 `TEAMID.com.gxutool.ios`，App 和小组件扩展共用同一个分组 | 用户 |
| 4.2 | 卸载 App 后重新安装 | iOS 默认会保留 Keychain：首次启动要正常处理（已保存的账号还在，或者提示重新登录），不能崩溃或卡在错误状态 | 用户 |
| 4.3 | **回前台刷新**：打开课表，切到别的 App 停留 5 分钟以上，再回来 | 课表自动刷新（顶部没有残留的旧错误），数据是新的 | 用户 |
| 4.4 | **断网**：开飞行模式后打开 App | 显示缓存数据和「上次更新于 …」提示，不弹空白页；恢复网络后下拉刷新恢复 | 用户 |
| 4.5 | **后台刷新 / Live Activity 更新**：锁屏放置较长时间（一节课时长） | 小组件、Live Activity 按时间线更新，不依赖 App 在前台 | 用户 |
| 4.6 | 登录过期（教务系统会话 7 天过期，可等或在别处登录挤掉）后打开 App | 自动用 Keychain 里的账号重新登录一次，用户无感知；密码已改则提示重新登录 | 用户 |

## 5. 上架前（单独做，需要 Team ID）

| # | 步骤 | 预期结果 | 谁 |
|---|---|---|---|
| 5.1 | **真实 iOS 18 验证（必须）**：另装 Xcode 16.x（约 3–5 GB，需 Apple ID）下载 iOS 18 runtime，或直接用一台 iOS 18 真机，跑一遍本清单第 1、2 节和 `run-e2e-ui.sh` 走查 | 玻璃降级（Material）分支外观正确；标签栏附件不盖住标签栏；没有只在 iOS 26+ 才有的 API 崩溃。目前只用 `-GxuForceLegacy` 在 iOS 27 模拟器上看过 | 用户装环境；A / B 跑走查和修问题 |
| 5.2 | `scripts/build.sh release` | 输出 `RELEASE BUILD OK`（干净构建的 Release + 真机架构） | A |
| 5.3 | `DEVELOPMENT_TEAM=<Team ID> scripts/archive.sh --check`，通过后 `scripts/archive.sh`（导出 .ipa）再 `scripts/archive.sh --upload`（上传 TestFlight） | `--check` 通过；archive 成功；构建在 App Store Connect 的 TestFlight 里处理完成。**注意**：Info.plist 里的版本号 / 构建号是写死的，`BUILD_NUMBER` 目前改不动实际版本（见 A 的 status「未验证的发现」），第二次上传前要先解决 | A；账号 / API Key 由用户提供 |
| 5.4 | 复核 `PrivacyInfo.xcprivacy` 声明，填写 App Store Connect 隐私营养标签和隐私政策链接 | 声明与实际收集一致 | 用户 |
| 5.5 | `version.json` 增加 `ios` 通道 | App 启动时能提示新版本并跳转 App Store / TestFlight；没有通道时静默 | 用户 |
| 5.6 | App 名称和图标 | 用中性名称和自制图标（避免「广西大学」名称和校徽的知识产权问题） | 用户 |
