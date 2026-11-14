import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import GxuTestSupport
import Testing
@testable import ExamUI

@MainActor
struct ScoreHistoryTests {
    private let scores = [
        Score(id: "math-first", year: 2024, term: 1, courseName: "高等数学", credit: 4, score: 55, teacherName: "教师甲"),
        Score(id: "math-retake", year: 2025, term: 2, courseName: "高等数学", credit: 4, score: 85, teacherName: "教师乙"),
        Score(id: "unknown-term", year: 2025, term: 0, courseName: "Academic Writing", credit: 2, score: 90, teacherName: "教师甲"),
    ]

    @Test func historyKeepsRetakesAndUnspecifiedTermsAndSearchesWithoutChangingSource() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/score", json: try JSONEncoder().encode(["data": ["items": scores]]))
        let services = AppServices.preview(backend: backend, features: [ExamRepository.migrations])
        let model = ScoreViewModel(services: services, query: .all)
        await model.load()
        #expect(Set(model.scores.map(\.id)) == Set(scores.map(\.id)))
        #expect(Set(ScoreHistory.matching(model.scores, query: " 数学 ").map(\.id)) == ["math-first", "math-retake"])
        #expect(Set(ScoreHistory.matching(model.scores, query: "教师甲").map(\.id)) == ["math-first", "unknown-term"])
        #expect(ScoreHistory.matching(model.scores, query: "academic").map(\.id) == ["unknown-term"])
        #expect(ScoreHistory.matching(model.scores, query: "不存在").isEmpty)
        #expect(ScoreHistory.matching(model.scores, query: "  ").count == 3)
        let groups = ScoreGroup.group(model.scores)
        #expect(groups.map(\.id) == ["2025-0", "2025-2", "2024-1"])
        #expect(ScoreHistory.title(for: try #require(groups.first)).contains("未标明学期"))
        #expect(model.scores.count == 3)
        #expect(backend.calls == ["GET /jw/score"])
    }

    @Test func successfulHistoryRefreshRemovesWithdrawnTermsAndEmptyHistory() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/score", json: try JSONEncoder().encode(["data": ["items": scores]]))
        let services = AppServices.preview(backend: backend, features: [ExamRepository.migrations])
        let model = ScoreViewModel(services: services, query: .all)
        await model.load()
        let repository = ExamRepository(database: services.database)
        let usual = [UsualScoreItem(name: "作业", ratio: "20", score: "90")]
        try await repository.saveUsualScores(usual, studentId: "2025000000", scoreId: "math-retake")
        try await repository.replaceAllScores(scores, studentId: "other-student")
        backend.stub("GET /jw/score", json: try JSONEncoder().encode(["data": ["items": [scores[1]]]]))
        await model.load()
        #expect(model.scores.map(\.id) == ["math-retake"])
        #expect(try await repository.usualScores(studentId: "2025000000", scoreId: "math-retake") == usual)
        backend.stub("GET /jw/score", json: #"{"data":{"items":[]}}"#)
        await model.load()
        #expect(model.scores.isEmpty)
        #expect(model.error == nil)
        #expect(try await repository.allScores(studentId: "other-student").count == 3)
    }

    @Test func failedHistoryRefreshPreservesVisibleRecords() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/score", json: try JSONEncoder().encode(["data": ["items": scores]]))
        let model = ScoreViewModel(services: .preview(backend: backend, features: [ExamRepository.migrations]), query: .all)
        await model.load()
        let cached = model.scores
        backend.stub("GET /jw/score", error: .network("offline"))
        await model.load()
        #expect(model.scores == cached)
        #expect(model.error != nil)
    }
}
