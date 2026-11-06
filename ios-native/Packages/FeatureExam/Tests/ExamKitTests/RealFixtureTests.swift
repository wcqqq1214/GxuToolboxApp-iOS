import Foundation
import GxuFoundation
import GxuTestSupport
import Testing
@testable import ExamKit

/// 用 A 抓取并脱敏的真实响应（`Fixtures/sanitized/`），期望值由 RN 同一公式在 python 里独立算出。
@Suite struct RealFixtureTests {
    private func backend() throws -> MockBackendAPI {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/exam", json: try loadFixture("exam", bundle: .module))
        mock.stub("GET /jw/score", json: try loadFixture("score", bundle: .module))
        mock.stub("GET /jw/score/usual", json: try loadFixture("score-usual", bundle: .module))
        return mock
    }

    @Test func examDecodesWithoutSeat() async throws {
        let exams = try await ExamAPI(backend: backend()).exams(AcademicTerm(year: 2025, term: 1))
        #expect(exams.count == 9)
        #expect(exams.allSatisfy { $0.seat.isEmpty && !$0.id.isEmpty && !$0.classroom.isEmpty })
        #expect(exams[0].time == "2026-01-23(09:00-11:00)")
        #expect(exams[0].course == "岩体力学")
    }

    @Test func examSectionsSplitAtNow() async throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = DateComponents(calendar: cal, year: 2025, month: 12, day: 20, hour: 12).date!
        let exams = try await ExamAPI(backend: backend()).exams(AcademicTerm(year: 2025, term: 1))
        let sections = ExamSorting.sections(exams.map { ExamItem($0, now: now, calendar: cal) })
        #expect(sections.upcoming.map(\.exam.course) == ["土力学", "材料力学", "岩体力学"])
        #expect(sections.past.count == 6)
        #expect(sections.past.first?.exam.course == "混凝土结构基本原理")
        #expect(sections.upcoming.first?.countdownText(now: now, calendar: cal) == "明日开考")
    }

    @Test func scoreDecodesIgnoringCamelCaseCopies() async throws {
        let scores = try await ScoreAPI(backend: backend()).scores(AcademicTerm(year: 2025, term: 1))
        #expect(scores.count == 100)
        #expect(scores.allSatisfy { $0.score != nil && $0.credit != nil })
        #expect(scores.filter { $0.term == 0 }.count == 1)
        #expect(Set(scores.map(\.id)).count == 100)
        #expect(scores.contains { $0.uploadAt.isEmpty })
        #expect(scores.first?.courseName == "中国近现代史纲要")
        #expect(scores.first?.credit == 2.5)
    }

    @Test func gpaMatchesReferenceFormula() async throws {
        let scores = try await ScoreAPI(backend: backend()).scores(AcademicTerm(year: 2025, term: 1))
        let all = GpaCalculator.calculate(scores)
        #expect(abs(all.gpa - 1.3977578475336323) < 1e-12)
        #expect(abs(all.wam - 52.912556053811656) < 1e-12)

        let t = GpaCalculator.calculate(scores.filter { $0.year == 2023 && $0.term == 1 })
        #expect(abs(t.gpa - 1.528301886792453) < 1e-12)
        #expect(abs(t.wam - 63.924528301886795) < 1e-12)

        let y = GpaCalculator.calculate(scores.filter { $0.year == 2023 && ($0.term == 1 || $0.term == 2) })
        #expect(abs(y.gpa - 1.3064516129032258) < 1e-12)
        #expect(abs(y.wam - 54.645161290322584) < 1e-12)
    }

    @Test func realScoresRoundTripThroughRepository() async throws {
        let scores = try await ScoreAPI(backend: backend()).scores(AcademicTerm(year: 2025, term: 1))
        let repo = ExamRepository(database: try .inMemory(features: [ExamRepository.migrations]))
        for term in 0...2 {
            try await repo.replaceScores(scores.filter { $0.year == 2022 && $0.term == term }, studentId: "s1", year: 2022, term: term)
        }
        let stored = try await repo.scores(studentId: "s1", year: 2022, term: 1)
        #expect(stored.count == 16)
        #expect(try await repo.scores(studentId: "s1", year: 2022, term: nil).count == 29)
        #expect(try await repo.scores(studentId: "s2", year: 2022, term: nil).isEmpty)
    }

    @Test func usualScoreEmptyIsNotCached() async throws {
        let items = try await ScoreAPI(backend: backend()).usualScores(year: 2025, term: 1, id: "x")
        #expect(items.isEmpty)
    }
}

/// 绩点计算器的"全部学期 / 全学年"汇总：用真实脱敏成绩（100 条，含 1 条 `term = 0` 的小学期），
/// 期望值由另一份独立的 Python 实现按 RN 的 useGpa 公式算出。
@Suite struct GpaAggregateFixtureTests {
    private func scores() throws -> [Score] {
        struct Page: Decodable { var items: [Score] }
        struct Envelope: Decodable { var data: Page }
        let url = try #require(Bundle.module.url(forResource: "score", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: url)).data.items
    }

    @Test func allTermsIncludingSummerTerm() throws {
        let all = try scores()
        #expect(all.count == 100 && all.filter { $0.term == 0 }.count == 1)
        let r = GpaCalculator.calculate(all)
        #expect(abs(r.gpa - 1.397758) < 1e-5 && abs(r.wam - 52.912556) < 1e-5)
        // 小学期那门（88 分，1 学分）计入汇总：去掉它结果不同
        let without = GpaCalculator.calculate(all.filter { $0.term != 0 })
        #expect(abs(without.gpa - 1.386937) < 1e-5 && abs(without.wam - 52.754505) < 1e-5)
    }

    @Test func wholeAcademicYearIsAutumnPlusSpring() throws {
        let year2023 = try scores().filter { $0.year == 2023 && ($0.term == 1 || $0.term == 2) }
        let r = GpaCalculator.calculate(year2023)
        #expect(year2023.count == 12)
        #expect(abs(r.gpa - 1.306452) < 1e-5 && abs(r.wam - 54.645161) < 1e-5)
    }

    @Test func groupsAreOrderedAndTitled() throws {
        let groups = ScoreGroup.group(try scores())
        #expect(groups.map(\.id) == ["2025-2", "2025-1", "2024-2", "2024-1", "2023-2", "2023-1", "2022-0", "2022-2", "2022-1"])
        #expect(groups.map { $0.scores.count } == [10, 14, 17, 18, 1, 11, 1, 12, 16])
        #expect(groups.first { $0.term == 0 }?.title == "2022–2023 小学期")
        #expect(groups[0].title == "2025–2026 春季" && groups[1].title == "2025–2026 秋季")
        #expect(groups.reduce(0) { $0 + $1.scores.count } == 100)
    }

    @Test func nilScoresAreSkippedInAggregate() {
        let list = [Score(id: "1", year: 2025, term: 1, courseName: "a", credit: 2, score: 90),
                    Score(id: "2", year: 2025, term: 1, courseName: "b", credit: 5, score: nil),
                    Score(id: "3", year: 2025, term: 0, courseName: "c", credit: 1, score: 60)]
        let r = GpaCalculator.calculate(list)
        #expect(abs(r.gpa - (4.0 * 2 + 1.0 * 1) / 3) < 1e-9)
        #expect(abs(r.wam - (180 + 60) / 3) < 1e-9)
    }
}
