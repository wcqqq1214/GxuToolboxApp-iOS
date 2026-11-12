import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Synchronization
import Testing
@testable import GxuAuth

private final class EventBackend: BackendAPI {
    let bodies = Mutex<[Data]>([])

    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("不支持的请求")
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        #expect(path == "/event")
        #expect(auth == nil)
        let data = try JSONEncoder().encode(body)
        bodies.withLock { $0.append(data) }
        return try JSONDecoder().decode(type, from: Data("{}".utf8))
    }
}

struct AnalyticsTests {
    @Test func defaultsToOffAndRechecksPreferenceForEveryEvent() async {
        let backend = MockBackendAPI()
        backend.stub("POST /event", json: "{}")
        let shared = InMemorySharedStore()
        let tracker = AnalyticsTracker(backend: backend, shared: shared)
        #expect(!tracker.isEnabled)
        await tracker.track("open_app", feature: "app")
        #expect(backend.calls.isEmpty)

        tracker.isEnabled = true
        await tracker.track("login_jw_success", feature: "login")
        #expect(backend.calls == ["POST /event"])

        AnalyticsTracker(backend: backend, shared: shared).isEnabled = false
        await tracker.track("open_app", feature: "app")
        await tracker.track("login_jw_success", feature: "login")
        #expect(backend.calls == ["POST /event"])
    }

    @Test func preferencePersistsAcrossStoreInstances() throws {
        let suite = "analytics-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let backend = MockBackendAPI()
        let tracker = AnalyticsTracker(backend: backend, shared: UserDefaultsSharedStore(suiteName: suite))
        tracker.isEnabled = true
        let reopened = AnalyticsTracker(backend: backend, shared: UserDefaultsSharedStore(suiteName: suite))
        #expect(reopened.isEnabled)
        reopened.isEnabled = false
        #expect(!AnalyticsTracker(backend: backend, shared: UserDefaultsSharedStore(suiteName: suite)).isEnabled)
    }

    @MainActor @Test func signedInServicesSendOnlyNonIdentifyingEventFields() async throws {
        let backend = EventBackend()
        let preview = AppServices.preview(studentId: "2025999999")
        let services = AppServices(backend: backend, database: preview.database, shared: preview.shared, accounts: preview.accounts)
        services.analytics.isEnabled = true
        await services.analytics.track("open_app", feature: "app")
        let data = try #require(backend.bodies.withLock { $0.first })
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == ["userId": "0", "eventName": "open_app", "feature": "app", "appVersion": AnalyticsTracker.appVersion])
        #expect(!String(decoding: data, as: UTF8.self).contains("2025999999"))
    }
}
