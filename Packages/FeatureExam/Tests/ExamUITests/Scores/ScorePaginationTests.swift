import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import Synchronization
import Testing
@testable import ExamUI

@MainActor
struct ScorePaginationTests {
    @Test func allHistoryMustFetchEveryReportedPageBeforeReplacingCache() async throws {
        let url = try #require(Bundle.module.url(forResource: "score", withExtension: "json", subdirectory: "Fixtures"))
        let firstPage = try Data(contentsOf: url)
        let tail = (0..<17).map { Score(id: "history-tail-\($0)", year: 2021, term: 2, courseName: "历史课程\($0)", credit: 1, score: 80) }
        let secondPage = try JSONEncoder().encode(["data": ScoreTestPage(totalCount: 117, totalPage: 2, currentPage: 2, items: tail)])
        let backend = PagedScoreBackend(firstPage: firstPage, secondPage: secondPage)
        let base = AppServices.preview(features: [ExamRepository.migrations])
        let services = AppServices(backend: backend, database: base.database, shared: base.shared, accounts: base.accounts)
        let repository = ExamRepository(database: services.database)
        try await repository.replaceAllScores(tail, studentId: "2025000000")
        let model = ScoreViewModel(services: services, query: .all)
        await model.load()
        let cached = try await repository.allScores(studentId: "2025000000")
        #expect(backend.pages == ["1", "2"])
        #expect(model.scores.count == 117)
        #expect(cached.filter { $0.id.hasPrefix("history-tail-") }.count == 17)
    }

    @Test(arguments: ["{", "{\"data\":null}", "{\"data\":{\"totalCount\":117,\"totalPage\":2,\"currentPage\":2,\"items\":[]}}"])
    func incompleteHistoryKeepsCache(secondPage: String) async throws {
        let url = try #require(Bundle.module.url(forResource: "score", withExtension: "json", subdirectory: "Fixtures"))
        let backend = PagedScoreBackend(firstPage: try Data(contentsOf: url), secondPage: Data(secondPage.utf8))
        let base = AppServices.preview(features: [ExamRepository.migrations])
        let services = AppServices(backend: backend, database: base.database, shared: base.shared, accounts: base.accounts)
        let repository = ExamRepository(database: services.database)
        let cached = Score(id: "cached", year: 2020, term: 1, courseName: "已缓存课程", credit: 2, score: 90)
        try await repository.replaceAllScores([cached], studentId: "2025000000")
        let model = ScoreViewModel(services: services, query: .all)
        await model.load()
        #expect(model.scores.map(\.id) == ["cached"])
        #expect(model.error != nil)
        #expect(try await repository.allScores(studentId: "2025000000").map(\.id) == ["cached"])
    }

}

private struct ScoreTestPage: Encodable {
    let totalCount: Int
    let totalPage: Int
    let currentPage: Int
    let items: [Score]
}

private final class PagedScoreBackend: BackendAPI {
    private let calls = Mutex<[String]>([])
    let firstPage: Data
    let secondPage: Data
    var pages: [String] { calls.withLock { $0 } }

    init(firstPage: Data, secondPage: Data) {
        self.firstPage = firstPage
        self.secondPage = secondPage
    }

    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        let page = query["pageNo"] ?? "missing"
        calls.withLock { $0.append(page) }
        return try JSONDecoder().decode(type, from: page == "2" ? secondPage : firstPage)
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.invalidData("Unexpected POST")
    }
}
