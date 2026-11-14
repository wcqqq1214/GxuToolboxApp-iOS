import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import Testing
@testable import ExamUI

private actor DelayedHistoryBackend: BackendAPI {
    private var calls = 0
    private var firstResponse: CheckedContinuation<Data, Never>?
    private let old = Data(#"{"data":{"items":[{"id":"old","year":2024,"term":1,"course_name":"旧学期课程","credit":2,"score":80}]}}"#.utf8)
    private let new = Data(#"{"data":{"items":[{"id":"old","year":2024,"term":1,"course_name":"旧学期课程","credit":2,"score":80},{"id":"new","year":2025,"term":2,"course_name":"新学期课程","credit":2,"score":90}]}}"#.utf8)

    func isWaiting() -> Bool { firstResponse != nil }
    func releaseFirst() {
        firstResponse?.resume(returning: old)
        firstResponse = nil
    }
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        calls += 1
        let response: Data
        if calls == 1 {
            response = await withCheckedContinuation { firstResponse = $0 }
        } else {
            response = new
        }
        return try JSONDecoder().decode(type, from: response)
    }
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("unused")
    }
}

@MainActor
struct ScoreRefreshTests {
    @Test func olderInitialLoadMustNotEraseNewerPullToRefreshResult() async throws {
        let backend = DelayedHistoryBackend()
        let preview = AppServices.preview(features: [ExamRepository.migrations])
        let services = AppServices(backend: backend, database: preview.database, shared: preview.shared, accounts: preview.accounts)
        let model = ScoreViewModel(services: services, query: .all)
        let initial = Task { await model.load() }
        while !(await backend.isWaiting()) { await Task.yield() }
        await model.load()
        #expect(Set(model.scores.map(\.id)) == ["old", "new"])
        await backend.releaseFirst()
        await initial.value
        let cached = try await ExamRepository(database: services.database).allScores(studentId: "2025000000")
        #expect(Set(model.scores.map(\.id)) == ["old", "new"])
        #expect(Set(cached.map(\.id)) == ["old", "new"])
    }
}
