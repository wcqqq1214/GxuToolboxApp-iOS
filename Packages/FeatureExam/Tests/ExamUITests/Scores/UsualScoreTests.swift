import ExamKit
import GxuAuth
import GxuTestSupport
import Testing
@testable import ExamUI

@MainActor
struct UsualScoreTests {
    @Test func retryUpdatesOnlyTheFailedCourseAndKeepsAnEmptyResponse() async {
        let backend = MockBackendAPI()
        let services = AppServices.preview(backend: backend, features: [ExamRepository.migrations], studentId: "demo-student")
        let model = ScoreViewModel(services: services)
        let first = Score(id: "math", year: 2026, term: 1, courseName: "数学", credit: 3, score: 90)
        let second = Score(id: "physics", year: 2026, term: 1, courseName: "物理", credit: 3, score: 88)

        backend.stub("GET /jw/score/usual", json: #"{"data":[{"name":"作业","ratio":"20","score":"95"}]}"#)
        await model.loadUsual(for: second)
        let secondResult = model.usual[second.id]
        #expect(secondResult == .loaded([UsualScoreItem(name: "作业", ratio: "20", score: "95")]))

        backend.stub("GET /jw/score/usual", error: .network("offline"))
        await model.loadUsual(for: first)
        #expect(model.usual[first.id] == .failed("获取平时成绩失败"))

        backend.stub("GET /jw/score/usual", json: #"{"data":[]}"#)
        await model.loadUsual(for: first)
        #expect(model.usual[first.id] == .loaded([]))
        #expect(model.usual[second.id] == secondResult)

        await model.loadUsual(for: first)
        #expect(model.usual[first.id] == .loaded([]))
        #expect(backend.calls == Array(repeating: "GET /jw/score/usual", count: 3))
    }
}
