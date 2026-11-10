import Foundation
import GxuFoundation
import GxuNetworking

private struct EventBody: Encodable, Sendable {
    let userId: String
    let eventName: String
    let feature: String
    let appVersion: String
}

private struct EventAck: Decodable, Sendable {}

/// 埋点（`POST /event`）。尽力而为：失败一律吞掉，绝不影响正常使用。
/// 事件：`open_app`/`app`（启动）、`login_jw_success`/`login`（教务登录成功）。
public struct AnalyticsTracker: Sendable {
    private let backend: any BackendAPI

    public init(backend: any BackendAPI) {
        self.backend = backend
    }

    /// App 版本号（`CFBundleShortVersionString`）
    public static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// 未登录时 userId 用 "0"（与 RN 一致）
    public func track(_ eventName: String, feature: String, userId: String?) async {
        let body = EventBody(userId: userId ?? "0", eventName: eventName, feature: feature, appVersion: Self.appVersion)
        _ = try? await backend.post("/event", body: body, auth: nil, as: EventAck.self)
    }
}

extension AppServices {
    public var analytics: AnalyticsTracker { AnalyticsTracker(backend: backend) }

    /// 在 MainActor 取学号后发送，调用方不需要等待
    @MainActor
    public func track(_ eventName: String, feature: String) {
        let tracker = analytics
        let userId = accounts.studentId
        Task { await tracker.track(eventName, feature: feature, userId: userId) }
    }
}
