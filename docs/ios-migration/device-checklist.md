# 真机验证清单

在仓库根目录运行 `scripts/run-device.sh --check` 检查签名和设备连接情况；如果用的是免费个人 Apple 账号，加上 `--personal`。需要看屏幕、登录真实账号或连校园网的步骤由测试者现场核对。

## 0. 准备条件

| 需要什么 | 说明 |
|---|---|
| 付费 Apple Developer Program 账号和 **Team ID** | 用来完整验证共享能力并上传 TestFlight（免费账号可以用下面的 `--personal` 模式装调试版）。Team ID 填到环境变量 `DEVELOPMENT_TEAM` 或 `.secrets/archive.env`（`DEVELOPMENT_TEAM=XXXXXXXXXX`），**不要提交到 git** |
| 一台 iPhone（iOS 18 或更高，最好另备一台 iOS 18.x 设备） | 数据线连电脑并解锁信任；打开「设置 → 隐私与安全性 → 开发者模式」；在 Xcode 里登录 Apple ID |
| 校园网或校园 VPN | 校外访问 CA、PEC、金工实训、OA 或校园网自服务受限时，切到校园网或校园 VPN |
| 校内账号 | 统一认证 `CA_USER` / `CA_PASS`、OA、考勤及教务账号。安装脚本不读这些凭据，直接在 App 里登录即可 |

**Team ID 怎么填：** 执行 `cp .secrets/archive.env.example .secrets/archive.env`，把里面的 `XXXXXXXXXX` 换成自己的 Team ID（`.secrets/archive.env` 已加入 gitignore，只提交模板 `archive.env.example`）。

**两种装法：**
- **数据线直装**：运行 `scripts/run-device.sh`（单台真机自动选中，多台时用 `--device <名称或UDID>`）。
- **导出 `.ipa` 给别人装**：运行 `scripts/run-device.sh --ipa`，包会输出到 `build/export/GxuToolApp.ipa`，结束时终端会打印路径和安装方式（Xcode 的 Devices and Simulators 窗口、Apple Configurator 或 `devicectl`）。注意装包的手机必须事先在 development 描述文件里登记过 UDID：先用数据线连一次 Xcode 自动登记，或者去 developer.apple.com 的 Devices 里手动添进去。

自动签名需要开发团队有权注册 App ID 和 App Group。默认 Bundle ID 是 `com.gxutool.ios`，如果被占用，可以通过 `BUNDLE_ID` 覆盖，Widget 和 App Group 标识会跟着联动。

## 0.5 只有免费 Apple 账号：`--personal` 模式

运行 `scripts/run-device.sh --personal`：
- **自动读取 Team ID**：优先从 Xcode 登录的个人团队或本地钥匙串的 Apple Development 证书获取，不用手填；如果有多个，脚本会打码列出，用 `DEVELOPMENT_TEAM=<完整 ID>` 指定即可。
- **修改 Bundle ID**：默认的 `com.gxutool.ios` 若报 `"cannot be registered … not available"`，说明被其他团队占用了，设置 `BUNDLE_ID=com.<你的名字>.gxutool`（环境变量或写进 `.secrets/archive.env`）。此时 Widget 自动用 `<BUNDLE_ID>.widget`，App Group 自动用 `group.<BUNDLE_ID>`。
- **能力不足时自动降级**：脚本会先尝试按完整能力（App Group + Keychain 共享）签名，只有 Xcode 明确报「个人团队不支持」时才自动切到去掉这两项的 Debug 构建，并打印实际生效的签名结论（只影响当次构建，不改 `project.yml`）。降级后 App 数据和偏好留在各自容器里，小组件读不到 App 数据而显示「未就绪」，App 本体不受影响。
- **7 天有效期**：免费账号的描述文件 7 天后失效，打不开时重新跑一遍这条命令重装就行。首次装好要在「设置 → 通用 → VPN 与设备管理」里信任开发者。一台手机最多装 3 个免费签名的 App，每周可注册的 App ID 数量也有限制，频繁换 `BUNDLE_ID` 会占掉名额。

**`--personal` 下的验证范围：**

| 测试项 | 能否验证 | 说明 |
|---|---|---|
| 第 2 节 大字号、VoiceOver | ✅ | 不受账号类型限制 |
| 第 3 节 账号与校园网功能（CA、PEC、金工实训、考勤、OA、校园网） | ✅ | 手机能连校园网并有账号即可 |
| 4.3 回前台刷新、4.4 断网缓存、4.6 过期自动重登 | ✅ | 正常可用 |
| 1.8 App Intents | ✅（App 内置 intent） | 能不能读到课表数据取决于签名有没有降级 |
| 1.1–1.7 小组件、Live Activity（共享数据） | 视结果而定 | 只有个人团队未降级（支持 App Group）时才能测，降级后小组件显示「未就绪」 |
| 4.1 Keychain access group（App 与扩展共享） | 视结果而定 | 同上，降级后主 App 和扩展各自使用自己的 Keychain |
| 4.2 卸载重装后的 Keychain 行为 | ✅ | 正常可用 |
| 5.1 真实 iOS 18 | ✅（需 iOS 18 手机） | 取决于设备系统版本 |
| 5.3 TestFlight、`archive.sh` 上传、`--ipa` 导出 | ❌ | 必须使用付费 Apple Developer Program 账号 |

## 1. 小组件、Live Activity 与 App Intents

| # | 操作步骤 | 预期结果 | 负责人 |
|---|---|---|---|
| 1.1 | 打开 App 登录教务账号，等课表加载完；回到主屏幕添加「西大工具箱」小组件，依次加上小、中、大三个尺寸 | 三个尺寸都能正常显示今天正在上和接下来的课，内容与「今天」页一致 | 用户 |
| 1.2 | 在锁屏添加「矩形」和「行内」小组件 | 显示下一节课的课名、时间和教室；行内样式一行完整不截断 | 用户 |
| 1.3 | **App Group 共享**：在 App 里下拉刷新课表，回主屏观察小组件 | 小组件在几秒到几分钟内同步更新，说明已正常读取 `group.<BUNDLE_ID>`。若长期空白或只显示占位，需排查扩展是否连到同一容器 | 用户（看屏幕）；可看设备日志里的 `Widget` 读写记录 |
| 1.4 | **切换账号**：设置 → 教务账号 → 退出登录，换另一个学号登录，回主屏看小组件 | 小组件立刻清空旧账号课表（空白或提示去登录，随后刷新成新账号课表），**不能残留上一位同学的课** | 用户（需准备第二个教务账号） |
| 1.5 | 挑选一节课开始和结束的前后几分钟观察小组件 | 到点自动切换到对应时间线条目 | 用户 |
| 1.6 | **Live Activity / 灵动岛**：在一节课开始前（处于提前显示窗口内）或上课中打开 App，观察锁屏与灵动岛 | 出现「当前课 / 下一节课」实时活动：倒计时和进度条正常走动，长按灵动岛展开样式正常，下课后自动结束 | 用户 |
| 1.7 | 实时活动显示期间锁屏、回主屏、上滑杀掉 App | 倒计时由系统继续驱动并按时更新，不会显示错误时间 | 用户 |
| 1.8 | **App Intents**：打开「快捷指令」，新建流程并搜索「西大工具箱」，分别跑一遍「今天的课」「明天的课」「下一场考试」；再对 Siri 说这几句话 | 返回与 App 内一致的文字播报；没有课表数据时给出明确引导，不会闪退 | 用户 |

## 2. 大字号（Dynamic Type）与 VoiceOver

| # | 操作步骤 | 预期结果 | 负责人 |
|---|---|---|---|
| 2.1 | 打开系统「设置 → 辅助功能 → 显示与文字大小 → 更大字体」，拉到最大（并打开「更大的辅助功能字体」），依次浏览 今天 / 课表 / 工具箱 / 考试 / 成绩 / 设置 / 账号页 / OA 文件 | 文字不截断、不重叠，列表和卡片自动撑高；周课表网格按设计限制在 xLarge 以内以保证可读 | 用户 |
| 2.2 | 保持大字号，在浅色和深色模式下再各过一遍 | 排版正常，文字与背景对比清晰 | 用户 |
| 2.3 | 打开 VoiceOver，在 今天 / 课表 / 工具箱 / 设置 里逐项滑动焦点 | 控件播报准确名称，工具箱图标不重复朗读；课程块念出课名、时间与教室；假期色带有完整文案；楼层图播报「双击放大」提示 | 用户 |
| 2.4 | 全程用 VoiceOver 操作：登录教务账号、查看成绩、展开平时分 | 只靠 VoiceOver 就能顺利走完整条链路 | 用户 |

## 3. 需要账号或校园网的功能

| # | 操作步骤 | 预期结果 | 负责人 |
|---|---|---|---|
| 3.1 | **CA 统一认证**：设置 → 统一认证账号 → 登录 | 登录成功；服务端明确拒绝时转述服务端提示，需要验证码、拒绝访问或服务异常时各自对应提示 | 用户（2026-11-06 已用真实账号通过模拟器登录校验，还需真机复核） |
| 3.2 | **PEC 物理实验课**：先登录统一认证并在校园网下打开「工具箱 → 实践课 → 物理实验课」 | 列表正常显示实验课，字段与 RN 一致（暂缺真机响应样本，届时顺便核对实际返回字段） | 用户 |
| 3.3 | **金工实训**：工具箱 → 实践课 → 金工实训 | 正常显示金工实训课表，`xlzxms` token 有效 | 用户 |
| 3.4 | **考勤**：设置 → 考勤账号 → 看验证码并登录；再到「工具箱 → 考勤信息」 | 登录顺利；验证码输错时自动换图提示；考勤按学期展示；token 过期（等一段时间或异地挤掉）后能正常提示重新登录 | 用户 |
| 3.5 | **OA 文件**：设置 → OA 账号登录；再到「工具箱 → 学校文件」 | 列表、分类筛选、标题搜索、翻页、正文都正常；PDF / DOCX 附件可预览；校外网络提示「OA 系统拒绝访问，可能需要连接校园网」 | 用户 |
| 3.6 | **校园网用量**：工具箱 → 信息查询 → 校园网用量，分别测试密码输错、未知登录失败和验证码重试 | 只有服务端 `tip` 开头明确指出密码错了，才提示检查密码；遇到「密码错误提示暂不可用」「密码错误次数过多」或其他登录失败统一用中性提示，原始 `tip` 经 `ErrorLog` 脱敏后记入诊断日志，验证码输入和重试互不干扰 | 用户 |
| 3.7 | 验证 PEC 和工程训练中心从 CAS 回跳到后续业务接口的全链路 HTTPS 支持情况 | 确认这两台主机的全部请求都能走通 HTTPS 后，再移除 `project.yml` 里的 HTTP 例外配置 | 开发者（完成 3.2 / 3.3 后） |
| 3.8 | 地图导航与教学楼平面图：点击地点导航按钮；打开教学楼楼层图并双指缩放 | Apple 地图按全名准确搜到校内位置；楼层图加载清晰，缩放跟手 | 用户 |
| 3.9 | 在校园网下和校外分别打开教师查询页检查头像 | App 会自动把广西大学的 HTTP 头像地址转为 HTTPS 以满足 ATS 要求；若校外因访问策略限制导致图片拉取失败，应回退显示姓名首字占位 | 用户 |

## 4. Keychain、后台更新与离线恢复

| # | 操作步骤 | 预期结果 | 负责人 |
|---|---|---|---|
| 4.1 | **Keychain 共享分组**：用真实 Team ID 装包后登录教务账号，杀掉 App 重开 | 保持已登录（没有 `-34018` 等凭据读写错误）。此时 `GxuConfig.keychainAccessGroup` 返回带 App Identifier Prefix 的共享分组（默认为 `<前缀>.com.gxutool.ios`），主 App 与小组件共用这一分组 | 用户 |
| 4.2 | 卸载 App 后重新安装 | iOS 默认会保留 Keychain 数据，重装首次启动能正确接管（延续账号或引导重登），不会闪退或卡死 | 用户 |
| 4.3 | **回前台自动刷新**：停留在课表页，切到其他 App 超过 5 分钟再切回来 | 课表自动刷新拿到新数据，顶部不残留旧报错 | 用户 |
| 4.4 | **离线缓存**：开启飞行模式后打开 App | 展示本地缓存并标注「上次更新于 …」，不显示空白页；恢复网络后下拉刷新恢复正常 | 用户 |
| 4.5 | **后台时间线更新**：锁屏放置约一节课时长 | 小组件与 Live Activity 按时间线正常切换，不依赖 App 留在前台 | 用户 |
| 4.6 | 登录态过期（教务会话约 7 天过期，或在别处登录挤下线）后重开 App | 自动用 Keychain 里的账号密码无感重登一次；如果密码已改，正常弹出重新登录提示 | 用户 |

## 5. 上架前检查（需要 Team ID）

| # | 操作步骤 | 预期结果 | 负责人 |
|---|---|---|---|
| 5.1 | **真实 iOS 18 验证（必做）**：在 iOS 18 真机上走查第 1、2 节；如果当前 Xcode 支持运行 iOS 18 模拟器，也可配好 E2E 测试账号并指定 `SIM_ID` 跑一遍 `bash scripts/run-e2e-ui.sh` | Material 降级样式正常，标签栏附件不会挡住标签栏，没有因误用 iOS 26+ 专属 API 引发的崩溃（`-GxuForceLegacy` 只能预览降级外观，不能代替真机兼容检查） | 用户 / 开发者 |
| 5.2 | 运行 `scripts/build.sh release` | 编译真机 Release 架构并输出 `RELEASE BUILD OK` | 开发者 |
| 5.3 | 配好 `DEVELOPMENT_TEAM` 后运行 `scripts/archive.sh --check`；用 `scripts/archive.sh` 导出 `.ipa` 或 `scripts/archive.sh --upload` 上传 TestFlight | `--check` 通过、archive 成功且 TestFlight 处理完成。版本号取自 `project.yml` 的 `MARKETING_VERSION`，构建号默认取 `CURRENT_PROJECT_VERSION`（可用 `BUILD_NUMBER` 覆盖），每次上传前记得递增并核对 App 与 Widget 构建号一致 | 开发者（上传账号由用户提供） |
| 5.4 | 核对 `PrivacyInfo.xcprivacy`，在 App Store Connect 填写隐私营养标签和隐私政策链接 | 声明与实际数据采集、使用行为完全一致 | 用户 |
| 5.5 | 在[发布版本清单](https://file.unde.site/GxuToolApp/version.json)的 `ios` 数组下配置版本信息 | 启动 App 时可正常提示更新并跳到 App Store 或 TestFlight；未配置通道时保持静默 | 用户 |
| 5.6 | 确认 App 名称与图标 | 上架前最终核对 Bundle ID、显示名称、应用图标及素材授权 | 用户 |

版本通道条目包含 `versionName`、整数 `versionCode`（用于与 `CFBundleVersion` 比较）、可选的 `desc`，以及 `ori.appStore` 或 `ori.testFlight` 的 HTTPS 链接。

使用 App Store Connect API Key 上传 TestFlight 时，把 `ASC_KEY_PATH`、`ASC_KEY_ID` 和 `ASC_ISSUER_ID` 填到本地归档配置中即可；也可以直接使用 Xcode 里已登录的 Apple ID 上传。
