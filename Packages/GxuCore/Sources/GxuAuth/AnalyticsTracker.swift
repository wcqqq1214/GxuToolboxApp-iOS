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

public struct AnalyticsTracker: Sendable {
    private let backend: any BackendAPI

    public init(backend: any BackendAPI) {
        self.backend = backend
    }

    public static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    public func track(_ eventName: String, feature: String, userId: String?) async {
        let body = EventBody(userId: userId ?? "0", eventName: eventName, feature: feature, appVersion: Self.appVersion)
        _ = try? await backend.post("/event", body: body, auth: nil, as: EventAck.self)
    }
}

extension AppServices {
    public var analytics: AnalyticsTracker { AnalyticsTracker(backend: backend) }

    @MainActor
    public func track(_ eventName: String, feature: String) {
        let tracker = analytics
        let userId = accounts.studentId
        Task { await tracker.track(eventName, feature: feature, userId: userId) }
    }
}
