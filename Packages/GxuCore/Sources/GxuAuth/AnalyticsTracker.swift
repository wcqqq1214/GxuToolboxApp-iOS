import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage

private struct EventBody: Encodable, Sendable {
    let userId: String
    let eventName: String
    let feature: String
    let appVersion: String
}

private struct EventAck: Decodable, Sendable {}

public struct AnalyticsTracker: Sendable {
    private let backend: any BackendAPI
    private let shared: any SharedStore
    private static let enabledKey = SharedKey<Bool>("privacy.analytics.enabled")

    public var isEnabled: Bool {
        get { shared.value(Self.enabledKey) ?? false }
        nonmutating set { shared.set(newValue, for: Self.enabledKey) }
    }

    public init(backend: any BackendAPI, shared: any SharedStore) {
        self.backend = backend
        self.shared = shared
    }

    public static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    public func track(_ eventName: String, feature: String) async {
        guard isEnabled else { return }
        let body = EventBody(userId: "0", eventName: eventName, feature: feature, appVersion: Self.appVersion)
        _ = try? await backend.post("/event", body: body, auth: nil, as: EventAck.self)
    }
}

extension AppServices {
    public var analytics: AnalyticsTracker { AnalyticsTracker(backend: backend, shared: shared) }

    @MainActor
    public func track(_ eventName: String, feature: String) {
        let tracker = analytics
        Task { await tracker.track(eventName, feature: feature) }
    }
}
