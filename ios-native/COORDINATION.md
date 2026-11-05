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

## Agent A 收到的请求

（暂无）

## Agent B 收到的请求

（暂无）

## Agent C 收到的请求

（暂无）
