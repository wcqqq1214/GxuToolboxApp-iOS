import Foundation
import GxuFoundation
import GxuTestSupport
import Testing
@testable import ExamKit

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
        #expect(sections.notPast.map(\.exam.course) == ["土力学", "材料力学", "岩体力学"])
        #expect(sections.past.count == 6)
        #expect(sections.past.first?.exam.course == "混凝土结构基本原理")
        #expect(sections.notPast.first?.countdownText(now: now, calendar: cal) == "明日开考")
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
        let without = GpaCalculator.calculate(all.filter { $0.term != 0 })
        #expect(abs(without.gpa - 1.386937) < 1e-5 && abs(without.wam - 52.754505) < 1e-5)
    }

    @Test func gpaMatchesReferenceForAutumnAndSpringScores() throws {
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

@Suite struct RetakeRuleFixtureTests {
    private func scores() throws -> [Score] {
        struct Page: Decodable { var items: [Score] }
        struct Envelope: Decodable { var data: Page }
        let url = try #require(Bundle.module.url(forResource: "score", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: url)).data.items
    }

    private func counted(_ name: String, in r: RetakeResolution) -> [Double?] {
        r.counted.filter { $0.courseName == name }.map(\.score)
    }

    @Test func allTermsBeforeAndAfter() throws {
        let all = try scores()
        let before = GpaCalculator.calculate(all)
        #expect(abs(before.gpa - 1.397758) < 1e-5 && abs(before.wam - 52.912556) < 1e-5)
        let r = RetakeRule.resolve(all)
        #expect(r.counted.count == 79 && r.overridden.count == 21 && r.retakeIDs.count == 10)
        let after = GpaCalculator.calculate(r.counted)
        #expect(abs(after.gpa - 2.037255) < 1e-5 && abs(after.wam - 69.679739) < 1e-5)
        #expect(Set(r.counted.map(\.id)).union(r.overridden.map(\.id)).count == 100)
    }

    @Test func eachCourseKeepsItsHighestScore() throws {
        let r = RetakeRule.resolve(try scores())
        #expect(counted("材料力学", in: r) == [61])
        #expect(counted("土力学", in: r) == [62])
        #expect(counted("混凝土结构基本原理", in: r) == [42])
        #expect(counted("岩体力学", in: r) == [47])
        #expect(counted("中国近现代史纲要", in: r) == [72])
        #expect(counted("高等数学A(上)", in: r) == [72])
        #expect(counted("基础工程", in: r) == [60] && counted("钢结构基本原理", in: r) == [60] && counted("地下结构设计原理", in: r) == [60])
        #expect(counted("结构力学（一）", in: r) == [33])
        let marked = r.counted.filter { r.retakeIDs.contains($0.id) }
        #expect(Set(marked.map(\.courseName)).count == 10 && marked.count == 10)
        #expect(Set(r.counted.map { "\($0.courseName)|\($0.credit ?? -1)" }).count == r.counted.count)
    }

    @Test func rangesMergeOnlyInsideTheirOwnRecords() throws {
        let all = try scores()
        func year(_ y: Int) -> [Score] { all.filter { $0.year == y && ($0.term == 1 || $0.term == 2) } }
        let expected: [(Int, Int, Int, Int, Double, Double)] = [
            (2025, 24, 18, 6, 1.691, 62.91), (2024, 35, 32, 3, 1.371795, 54.051282),
            (2023, 12, 11, 1, 1.528302, 63.924528), (2022, 28, 27, 1, 1.992233, 70.019417),
        ]
        for (y, total, kept, marks, gpa, wam) in expected {
            let r = RetakeRule.resolve(year(y))
            #expect(year(y).count == total && r.counted.count == kept && r.retakeIDs.count == marks, "\(y)")
            let g = GpaCalculator.calculate(r.counted)
            #expect(abs(g.gpa - gpa) < 1e-5 && abs(g.wam - wam) < 1e-5, "\(y)")
        }
    }

    @Test func singleTermIsUntouched() throws {
        let t = try scores().filter { $0.year == 2025 && $0.term == 1 }
        let r = RetakeRule.resolve(t)
        #expect(r.counted == t && r.overridden.isEmpty && r.retakeIDs.isEmpty)
        #expect(GpaCalculator.calculate(r.counted) == GpaCalculator.calculate(t))
    }
}

@Suite struct RetakeRuleEdgeCaseTests {
    private func s(_ id: String, _ name: String, _ credit: Double?, _ score: Double?, y: Int = 2025, t: Int = 1, at: String = "") -> Score {
        Score(id: id, year: y, term: t, courseName: name, credit: credit, score: score, uploadAt: at)
    }

    @Test func samePassingCourseIsCountedOnceWithHighestScore() {
        let list = [s("1", "体育", 1, 80, y: 2023), s("2", "体育", 1, 90, y: 2024), s("3", "体育", 1, 70, y: 2025)]
        let r = RetakeRule.resolve(list)
        #expect(r.counted.map(\.id) == ["2"] && r.overridden.count == 2 && r.retakeIDs == ["2"])
    }

    @Test func differentCreditsAreDifferentCourses() {
        let r = RetakeRule.resolve([s("1", "高数", 4, 40, y: 2023), s("2", "高数", 5, 90, y: 2024)])
        #expect(r.counted.count == 2 && r.overridden.isEmpty && r.retakeIDs.isEmpty)
    }

    @Test func highestWinsWhateverTheOrder() {
        #expect(RetakeRule.resolve([s("1", "A", 2, 70, y: 2023), s("2", "A", 2, 30, y: 2024)]).counted.map(\.id) == ["1"])
        #expect(RetakeRule.resolve([s("1", "A", 2, 70, y: 2023), s("2", "A", 2, 30, y: 2024), s("3", "A", 2, 80, y: 2025)]).counted.map(\.id) == ["3"])
        #expect(RetakeRule.resolve([s("1", "A", 2, 30, y: 2023), s("2", "A", 2, 20, y: 2024)]).counted.map(\.id) == ["1"])
    }

    @Test func tieTakesTheNewest() {
        let r = RetakeRule.resolve([s("spring", "C", 2, 65, y: 2025, t: 2), s("sum", "C", 2, 65, y: 2025, t: 0)])
        #expect(r.counted.map(\.id) == ["sum"])
        let r2 = RetakeRule.resolve([s("blank", "E", 2, 70, at: ""), s("late", "E", 2, 70, at: "2026-01-20 10:00:00"), s("early", "E", 2, 70, at: "2026-01-10 10:00:00")])
        #expect(r2.counted.map(\.id) == ["late"])
        let r3 = RetakeRule.resolve([s("new", "F", 2, 70, y: 2026, t: 1, at: ""), s("old", "F", 2, 70, y: 2025, t: 2, at: "2099-01-01 00:00:00")])
        #expect(r3.counted.map(\.id) == ["new"])
    }

    @Test func recordsWithoutScoreDoNotCompete() {
        let r = RetakeRule.resolve([s("1", "G", 3, 30, y: 2024), s("2", "G", 3, nil, y: 2025)])
        #expect(r.counted.map(\.id) == ["1"])
        let none = RetakeRule.resolve([s("1", "H", 3, nil), s("2", "H", 3, nil, y: 2026)])
        #expect(none.counted.count == 2)
    }

    @Test func emptyAndSingleInputs() {
        #expect(RetakeRule.resolve([]) == RetakeResolution(counted: [], overridden: [], retakeIDs: []))
        let one = [s("1", "I", 2, 10)]
        #expect(RetakeRule.resolve(one).counted == one && RetakeRule.resolve(one).retakeIDs.isEmpty)
    }

    @Test func formulaAndDenominatorUnchanged() {
        let list = [s("1", "a", 3, 90), s("2", "b", 2, 75), s("3", "c", 1, 59), s("4", "d", 2, 60)]
        let r = GpaCalculator.calculate(RetakeRule.resolve(list).counted)
        #expect(abs(r.gpa - 2.375) < 1e-9 && abs(r.wam - 74.875) < 1e-9)
        let twice = GpaCalculator.calculate(RetakeRule.resolve([s("1", "x", 3, 40, y: 2024), s("2", "x", 3, 70, y: 2025)]).counted)
        #expect(abs(twice.gpa - 2.0) < 1e-9 && abs(twice.wam - 70) < 1e-9)
    }
}
