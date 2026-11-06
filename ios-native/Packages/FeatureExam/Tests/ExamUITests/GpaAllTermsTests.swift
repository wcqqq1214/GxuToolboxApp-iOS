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
        #expect(abs(model.gpa.gpa - 1.397758) < 1e-5 && abs(model.gpa.wam - 52.912556) < 1e-5)
        #expect(model.error == nil && model.lastSyncedAt != nil && model.pending.isEmpty)
        // 只发了一次请求（不是逐学年、逐学期循环）
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
        #expect(model.scores.count == 100)                    // 有缓存：保留
        #expect(model.error != nil)                            // 并提示
        #expect(abs(model.gpa.gpa - 1.397758) < 1e-5)

        // 没有缓存又失败：没有任何成绩，界面据此隐藏数字
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
        #expect(mock.calls == ["GET /jw/score"])   // 单个学期：一次请求
        #expect(!model.query.isAll)
        let wholeYear = MockBackendAPI()
        wholeYear.stub("GET /jw/score", json: Data(#"{"data":{"items":[]}}"#.utf8))
        await ScoreViewModel(services: services(wholeYear), query: .init(year: 2025, term: nil)).load()
        #expect(wholeYear.calls == ["GET /jw/score", "GET /jw/score"])   // 全学年：秋、春各一次
    }
}

private extension MockBackendAPI {
    func failing() -> MockBackendAPI {
        stub("GET /jw/score", error: GxuError.network("offline"))
        return self
    }
}
