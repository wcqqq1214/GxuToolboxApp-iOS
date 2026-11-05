import Foundation
import GxuFoundation
import GxuStorage
import GxuTestSupport
import Testing
@testable import ExamKit

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

@Suite struct DecodingTests {
    @Test func examWithoutSeat() throws {
        let e = try decode(Exam.self, #"{"id":"e1","course":"计算机网络原理","classroom":"6A-408","time":"2026-07-15(09:00-11:00)","type":"期末"}"#)
        #expect(e.seat == "")
        #expect(e.classroom == "6A-408")
    }

    @Test func examWithEmptyTime() throws {
        let e = try decode(Exam.self, #"{"id":"e1","course":"x","classroom":"","time":"","type":""}"#)
        #expect(e.time == "")
    }

    @Test func scoreSnakeCaseWithNullScore() throws {
        let s = try decode(Score.self, #"{"id":"j1","year":2025,"term":2,"course_name":"数据结构","credit":3.5,"score":null,"teacher_name":"某老师","upload_at":"2026-07-13 16:00:12"}"#)
        #expect(s.score == nil)
        #expect(s.credit == 3.5)
        #expect(s.courseName == "数据结构")
        #expect(s.uploadAt == "2026-07-13 16:00:12")
    }

    @Test func scoreTermZeroAndCamelFallback() throws {
        let s = try decode(Score.self, #"{"id":"j1","year":2025,"term":0,"courseName":"工程训练","credit":1,"score":90}"#)
        #expect(s.term == 0)
        #expect(s.courseName == "工程训练")
    }

    @Test func usualScoreRatio() throws {
        let list = try decode([UsualScoreItem].self, #"[{"name":"平时成绩","ratio":"30","score":"91"},{"name":"总评","ratio":"N/A","score":"90"}"#.appending("]"))
        #expect(list[0].hasRatio)
        #expect(!list[1].hasRatio)
    }
}

@Suite struct APITests {
    @Test func nullExamDataIsEmpty() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/exam", json: #"{"data":null}"#)
        #expect(try await ExamAPI(backend: mock).exams(AcademicTerm(year: 2025, term: 2)).isEmpty)
        #expect(mock.calls == ["GET /jw/exam"])
    }

    @Test func scoresDecodePage() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/score", json: #"{"code":200,"message":"","data":{"totalCount":1,"totalPage":1,"currentPage":1,"items":[{"id":"j1","year":2025,"term":1,"course_name":"A","credit":2,"score":88,"teacher_name":"t","upload_at":"2026-01-10 10:00:00"}]}}"#)
        let list = try await ScoreAPI(backend: mock).scores(AcademicTerm(year: 2025, term: 1))
        #expect(list.map(\.id) == ["j1"])
    }

    @Test func errorPropagates() async {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/exam", error: .sessionExpired(.jw))
        await #expect(throws: GxuError.sessionExpired(.jw)) {
            try await ExamAPI(backend: mock).exams(AcademicTerm(year: 2025, term: 1))
        }
    }
}

@Suite struct RepositoryTests {
    let repo: ExamRepository
    let term = AcademicTerm(year: 2025, term: 2)

    init() throws {
        repo = ExamRepository(database: try .inMemory(features: [ExamRepository.migrations]))
    }

    private func exam(_ id: String) -> Exam {
        Exam(id: id, course: id, classroom: "r", time: "2026-07-15(09:00-11:00)", type: "t")
    }

    private func score(_ id: String, term: Int = 2) -> Score {
        Score(id: id, year: 2025, term: term, courseName: id, credit: 2, score: 80, uploadAt: "2026-07-01 00:00:00")
    }

    @Test func examsAreIsolatedByStudent() async throws {
        try await repo.replaceExams([exam("a")], studentId: "s1", term: term)
        try await repo.replaceExams([exam("b")], studentId: "s2", term: term)
        #expect(try await repo.exams(studentId: "s1", term: term).map(\.id) == ["a"])
        #expect(try await repo.exams(studentId: "s2", term: term).map(\.id) == ["b"])
    }

    @Test func replaceExamsDropsCancelledAndHandlesEmpty() async throws {
        try await repo.replaceExams([exam("a"), exam("b")], studentId: "s1", term: term)
        try await repo.replaceExams([exam("b")], studentId: "s1", term: term)
        #expect(try await repo.exams(studentId: "s1", term: term).map(\.id) == ["b"])
        try await repo.replaceExams([], studentId: "s1", term: term)
        #expect(try await repo.exams(studentId: "s1", term: term).isEmpty)
    }

    @Test func replaceExamsOnlyTouchesOneTerm() async throws {
        let other = AcademicTerm(year: 2025, term: 1)
        try await repo.replaceExams([exam("a")], studentId: "s1", term: other)
        try await repo.replaceExams([exam("b")], studentId: "s1", term: term)
        try await repo.replaceExams([], studentId: "s1", term: term)
        #expect(try await repo.exams(studentId: "s1", term: other).map(\.id) == ["a"])
    }

    @Test func scoresAreIsolatedByStudentAndNotDuplicated() async throws {
        try await repo.replaceScores([score("j1")], studentId: "s1", year: 2025, term: 2)
        try await repo.replaceScores([score("j1")], studentId: "s1", year: 2025, term: 2)
        try await repo.replaceScores([score("j1")], studentId: "s2", year: 2025, term: 2)
        #expect(try await repo.scores(studentId: "s1", year: 2025, term: 2).count == 1)
        #expect(try await repo.scores(studentId: "s2", year: 2025, term: nil).count == 1)
        #expect(try await repo.scores(studentId: "s3", year: 2025, term: nil).isEmpty)
    }

    @Test func refreshKeepsUsualScoresAndPrunesRemoved() async throws {
        try await repo.replaceScores([score("j1"), score("j2")], studentId: "s1", year: 2025, term: 2)
        try await repo.saveUsualScores([UsualScoreItem(name: "平时成绩", ratio: "30", score: "91")], studentId: "s1", scoreId: "j1")
        try await repo.replaceScores([score("j1")], studentId: "s1", year: 2025, term: 2)
        #expect(try await repo.scores(studentId: "s1", year: 2025, term: 2).map(\.id) == ["j1"])
        #expect(try await repo.usualScores(studentId: "s1", scoreId: "j1")?.first?.score == "91")
        #expect(try await repo.usualScores(studentId: "s2", scoreId: "j1") == nil)
    }

    @Test func emptyUsualScoresAreNotCached() async throws {
        try await repo.replaceScores([score("j1")], studentId: "s1", year: 2025, term: 2)
        try await repo.saveUsualScores([], studentId: "s1", scoreId: "j1")
        #expect(try await repo.usualScores(studentId: "s1", scoreId: "j1") == nil)
    }

    @Test func wholeYearQueryAndOrdering() async throws {
        var a = score("a", term: 1); a.uploadAt = "2026-01-10 00:00:00"
        var b = score("b", term: 2); b.uploadAt = "2026-07-10 00:00:00"
        try await repo.replaceScores([a], studentId: "s1", year: 2025, term: 1)
        try await repo.replaceScores([b], studentId: "s1", year: 2025, term: 2)
        #expect(try await repo.scores(studentId: "s1", year: 2025, term: nil).map(\.id) == ["b", "a"])
        #expect(try await repo.lastSyncedAt(studentId: "s1", year: 2025, term: nil) != nil)
        #expect(try await repo.lastSyncedAt(studentId: "s1", year: 2024, term: nil) == nil)
    }
}
