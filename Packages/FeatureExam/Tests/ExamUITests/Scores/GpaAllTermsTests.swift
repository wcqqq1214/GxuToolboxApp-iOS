import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import GxuStorage
import GxuTestSupport
import Testing
@testable import ExamUI

@MainActor @Suite struct GpaAllTermsTests {
    private func fixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "score", withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private func services(_ mock: MockBackendAPI, studentId: String = "2025000000") -> AppServices {
        .preview(backend: mock, features: [ExamRepository.migrations], studentId: studentId)
    }

    @Test func allTermsLoadsEverythingFromOneUnfilteredRequest() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/score", json: try fixture())
        let model = ScoreViewModel(services: services(mock), query: .all)
        await model.load()
        #expect(model.scores.count == 100)
        #expect(model.resolved.counted.count == 79)
        #expect(abs(model.gpa.gpa - 2.037255) < 1e-5 && abs(model.gpa.wam - 69.679739) < 1e-5)
        #expect(abs(GpaCalculator.calculate(model.scores).gpa - 1.397758) < 1e-5)
        #expect(model.error == nil && model.lastSyncedAt != nil && model.pending.isEmpty)
        #expect(mock.calls == ["GET /jw/score"])
    }

    @Test func failureKeepsCacheAndShowsErrorButNeverAWrongTotal() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/score", json: try fixture())
        let s = services(mock)
        let model = ScoreViewModel(services: s, query: .all)
        await model.load()
        mock.stub("GET /jw/score", error: GxuError.network("offline"))
        await model.load()
        #expect(model.scores.count == 100)
        #expect(model.error != nil)
        #expect(abs(model.gpa.gpa - 2.037255) < 1e-5)

        let empty = ScoreViewModel(services: services(MockBackendAPI().failing()), query: .all)
        await empty.load()
        #expect(empty.scores.isEmpty && empty.error != nil)
    }

    @Test func signedOutAccountSeesNothing() async {
        let model = ScoreViewModel(services: .preview(signedIn: false), query: .all)
        await model.load()
        #expect(model.scores.isEmpty && model.error == .notLoggedIn(.jw))
    }

    @Test func singleTermQueryStillUsesTermRequests() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/score", json: Data(#"{"data":{"items":[]}}"#.utf8))
        let model = ScoreViewModel(services: services(mock), query: .init(year: 2025, term: 1))
        await model.load()
        #expect(mock.calls == ["GET /jw/score"])
        #expect(!model.query.isAll)
        let wholeYear = MockBackendAPI()
        wholeYear.stub("GET /jw/score", json: Data(#"{"data":{"items":[]}}"#.utf8))
        await ScoreViewModel(services: services(wholeYear), query: .init(year: 2025, term: nil)).load()
        #expect(wholeYear.calls == ["GET /jw/score", "GET /jw/score"])
    }
}

private extension MockBackendAPI {
    func failing() -> MockBackendAPI {
        stub("GET /jw/score", error: GxuError.network("offline"))
        return self
    }
}

@MainActor @Suite struct GpaRetakeViewModelTests {
    private func fixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "score", withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test func singleTermQueryIsNotRewrittenByLaterTerms() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/score", json: try fixture())
        let services = AppServices.preview(backend: mock, features: [ExamRepository.migrations])
        await ScoreViewModel(services: services, query: .all).load()
        let items = (try await ExamRepository(database: services.database).scores(studentId: "2025000000", year: 2024, term: 1))
        let single = ScoreViewModel(services: services, query: .init(year: 2024, term: 1))
        await single.load()
        #expect(single.scores.count == items.count && !items.isEmpty)
        #expect(items.count == 18 && single.resolved.counted.count == 18)
    }

    @Test func accountsDoNotMix() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/score", json: try fixture())
        let a = AppServices.preview(backend: mock, features: [ExamRepository.migrations], studentId: "s1")
        await ScoreViewModel(services: a, query: .all).load()
        let other = AppServices.preview(backend: MockBackendAPI(), studentId: "s2")
        let shared = AppServices(backend: MockBackendAPI(), database: a.database, shared: other.shared, accounts: other.accounts)
        let model = ScoreViewModel(services: shared, query: .all)
        await model.load()
        #expect(model.scores.isEmpty && model.resolved.counted.isEmpty && model.gpa == .zero)
    }
}
