import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import Testing
@testable import FeatureMisc

final class GateBackend: BackendAPI, @unchecked Sendable {
    private let lock = NSLock()
    private var conts: [String: CheckedContinuation<Void, Never>] = [:]
    private var hangKeys: Set<String> = []
    var arrived: Set<String> { lock.withLock { Set(conts.keys) } }
    func hang(_ k: String) { lock.withLock { _ = hangKeys.insert(k) } }
    func release(_ k: String) { lock.withLock { conts.removeValue(forKey: k) }?.resume() }
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        let key = "\(query["q"] ?? "")#\(query["page"] ?? "1")"
        if lock.withLock({ hangKeys.contains(key) }) {
            await withCheckedContinuation { c in lock.withLock { conts[key] = c } }
        }
        let q = query["q"] ?? ""
        let json = #"{"data":{"list":[{"id":"\#(q)\#(query["page"] ?? "1")","name":"\#(q)","unit":"u"}],"pages":3,"total":3}}"#
        return try JSONDecoder().decode(type, from: Data(json.utf8))
    }
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T { fatalError() }
}

@MainActor @Suite struct TeacherSearchRaceTests {
    @Test func loadMoreSupersededBySearchDoesNotKillPagination() async throws {
        let b = GateBackend()
        let services = AppServices(backend: b, database: AppServices.preview().database, shared: AppServices.preview().shared, accounts: AppServices.preview().accounts)
        let m = TeacherSearchModel(services: services)
        m.draftQuery = "a"; await m.search()
        b.hang("a#2")
        let t = Task { await m.loadMore() }
        while !b.arrived.contains("a#2") { await Task.yield() }
        m.draftQuery = "b"; await m.search()
        b.release("a#2"); await t.value
        #expect(!m.isLoadingMore)
        await m.loadMore()
        #expect(m.results.map(\.id) == ["b1", "b2"])
    }
}
