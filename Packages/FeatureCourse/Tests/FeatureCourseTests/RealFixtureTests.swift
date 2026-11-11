import ExamKit
import Foundation
import GxuFoundation
import GxuStorage
import ScheduleKit
import Testing
@testable import FeatureCourse

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

private struct Envelope<T: Decodable>: Decodable { var data: T }
private struct Page<T: Decodable>: Decodable { var items: [T] }

private func selectedAll() throws -> [SelectedCourse] {
    try JSONDecoder().decode(Envelope<Page<SelectedCourse>>.self, from: fixture("selected-courses")).data.items
}

private func passedNames(adding extra: [String] = []) throws -> Set<String> {
    let scores = try JSONDecoder().decode(Envelope<Page<Score>>.self, from: fixture("score")).data.items
    return Set(ElectiveStrategyViewModel.passed(scores).keys).union(extra)
}

@Suite struct SelectedCourseFixtureTests {
    @Test func decodesEveryItemWithoutLoss() throws {
        let items = try selectedAll()
        #expect(items.count == 135)
        #expect(items.allSatisfy { !$0.classId.isEmpty && !$0.courseName.isEmpty && $0.credit >= 0 })
        #expect(items.filter { $0.credit == 0 }.count == 11)
        #expect(Dictionary(grouping: items, by: \.type).mapValues(\.count) == ["理论": 100, "实验": 19, "实践": 13, "实习": 3])
        #expect(Dictionary(grouping: items, by: \.term).mapValues(\.count) == [1: 81, 2: 53, 3: 1])
        #expect(items.filter { $0.selectionType == "通识选修课" }.count == 12)
        #expect(items.filter { $0.location.isEmpty }.count == 28)
        #expect(items.filter { $0.location.contains(";") }.count == 63)
        #expect(Set(items.map(\.id)).count == 135)
        #expect(items.contains { $0.credit == 4.5 } && items.contains { $0.credit == 1 })
    }

    @Test func termFileMatchesAllFileSlice() throws {
        let term = try JSONDecoder().decode(Envelope<Page<SelectedCourse>>.self, from: fixture("selected-courses-term")).data.items
        #expect(term.count == 17)
        #expect(term.allSatisfy { $0.year == 2025 && $0.term == 1 })
        let fromAll = try selectedAll().filter { $0.year == 2025 && $0.term == 1 }
        #expect(Set(term.map(\.classId)) == Set(fromAll.map(\.classId)))
    }

    @Test func onlineCoursesAreTheSevenPlaceholderTeacherOnes() throws {
        let items = try selectedAll()
        #expect(items.filter(\.isOnline).count == 7)
        #expect(items.filter { $0.isOnline && $0.selectionType == "通识选修课" }.count == 6)
        #expect(items.filter(\.isLab).count == 19)
        #expect(items.filter { $0.isLab }.allSatisfy { $0.type == "实验" })
    }

    @Test func repositoryAcceptsTermThreeAndIsolatesStudents() async throws {
        let db = try AppDatabase.inMemory(features: [CourseFeature.migrations])
        let repo = SelectedCourseRepository(database: db)
        let all = try selectedAll()
        try await repo.replaceAll(all, studentId: "a")
        #expect(try await repo.list(studentId: "a", scope: .all).count == 135)
        #expect(try await repo.list(studentId: "a", scope: .term(AcademicTerm(year: 2022, term: 3))).count == 1)
        #expect(try await repo.list(studentId: "b", scope: .all).isEmpty)
        let term = try JSONDecoder().decode(Envelope<Page<SelectedCourse>>.self, from: fixture("selected-courses-term")).data.items
        try await repo.replaceTerm(term, studentId: "a", term: AcademicTerm(year: 2025, term: 1))
        #expect(try await repo.list(studentId: "a", scope: .term(AcademicTerm(year: 2025, term: 1))).count == 17)
        #expect(try await repo.list(studentId: "a", scope: .all).count == 135)
        let stored = try await repo.list(studentId: "a", scope: .term(AcademicTerm(year: 2025, term: 1)))
        #expect(Set(stored.map(\.location)) == Set(term.map(\.location)))
        await #expect(throws: GxuError.self) { try await repo.replaceTerm(all, studentId: "c", term: AcademicTerm(year: 2025, term: 1)) }
        #expect(try await repo.list(studentId: "c", scope: .all).isEmpty)
    }

    @Test func groupsAreOrderedAndNamedIncludingSummerTerm() throws {
        let groups = SelectedCourseGroup.group(try selectedAll())
        #expect(groups.first?.year == 2026)
        #expect(groups.map { "\($0.year)-\($0.term)" } == groups.map { "\($0.year)-\($0.term)" }.sorted(by: >))
        #expect(groups.first { $0.year == 2022 && $0.term == 3 }?.title == "2022–2023 小学期")
        #expect(groups.reduce(0) { $0 + $1.courses.count } == 135)
        #expect(SelectedCourseGroup.group(try selectedAll(), matching: "材料力学").flatMap(\.courses).allSatisfy { $0.courseName.contains("材料力学") })
    }

    @Test func pendingForTermExcludesEmbeddedLabs() throws {
        let term = try JSONDecoder().decode(Envelope<Page<SelectedCourse>>.self, from: fixture("selected-courses-term")).data.items
        let scores = try JSONDecoder().decode(Envelope<Page<Score>>.self, from: fixture("score")).data.items
        let scoredNames = Set(scores.filter { $0.year == 2025 && $0.term == 1 }.map(\.courseName))
        let scoredIds = Set(term.filter { scoredNames.contains($0.courseName) && !$0.isLab }.map(\.classId))
        let pending = PendingCourse.diff(
            selected: term.map { PendingCourse(id: $0.classId, name: $0.courseName, isLab: $0.isLab, courseId: $0.courseId) }, scoredIds: scoredIds
        )
        #expect(pending.map(\.displayName) == ["形势与政策（7）", "创新创业实践"])
    }
}

@Suite struct ElectiveStrategyFixtureTests {
    private func general() throws -> [SelectedCourse] { try selectedAll().filter { $0.selectionType == "通识选修课" } }

    private func stats(grade: Int, passed: Set<String>) throws -> ElectiveStats {
        ElectiveStrategies.strategy(forGrade: grade).calculate(try general().filter { passed.contains($0.courseName) })
    }

    @Test func fixtureHasElevenOfTwelvePassedGeneralCourses() throws {
        let names = try passedNames()
        #expect(try general().filter { names.contains($0.courseName) }.count == 11)
        #expect(!names.contains("中文写作实训"))
    }

    @Test func moduleKeywordsMatchRealSystemNames() throws {
        let s = try stats(grade: 2022, passed: try passedNames())
        #expect(s.totalScore == 12 && s.offlineScore == 6)
        #expect(s.lead.score == 3 && s.entrepreneurship.score == 2 && s.art.score == 3)
        #expect(s.asean.score == 1 && s.ethnic.score == 1 && s.ocean.score == 2)
        #expect(s.specialModulesCount == 3)
    }

    @Test(arguments: [(2021, ["中文写作实训"]), (2022, ["中文写作实训"]), (2023, ["中文写作实训", "中华民族共同体概论"]), (2024, ["中文写作实训", "中华民族共同体概论"]), (2025, ["创新创业基础"]), (2026, ["创新创业基础"])])
    func missingRequiredCourseBlocksQualification(grade: Int, remaining: [String]) throws {
        let s = try stats(grade: grade, passed: try passedNames())
        #expect(s.remainingRequired == remaining)
        #expect(s.passed["requiredCourses"] == false)
        #expect(!s.isQualified)
        #expect(s.passed.filter { $0.key != "requiredCourses" }.values.allSatisfy { $0 })
    }

    @Test func gradeTwentyTwentyTwoQualifiesOnceWritingCourseIsPassed() throws {
        let s = try stats(grade: 2022, passed: try passedNames(adding: ["中文写作实训"]))
        #expect(s.remainingRequired.isEmpty)
        #expect(s.isQualified)
        #expect(s.totalScore == 12.5 && s.offlineScore == 6.5 && s.lead.score == 3.5)
        #expect(ElectiveStrategies.strategy(forGrade: 2022).rows(s).allSatisfy { $0.passed })
    }

    @Test func gradeTwentyTwentyOneFailsOnOfflineRatioOnceWritingCourseIsPassed() throws {
        let s = try stats(grade: 2021, passed: try passedNames(adding: ["中文写作实训"]))
        #expect(s.remainingRequired.isEmpty)
        #expect(s.passed["offlineScore"] == false)
        #expect(!s.isQualified)
    }

    @Test func grades2023And2024StillNeedNationalityCourse() throws {
        for g in [2023, 2024] {
            let s = try stats(grade: g, passed: try passedNames(adding: ["中文写作实训"]))
            #expect(s.remainingRequired == ["中华民族共同体概论"])
            #expect(!s.isQualified)
        }
    }

    @Test func modernGradesNeedModuleCreditsAndRequiredCourse() throws {
        for g in [2025, 2026] {
            let s = try stats(grade: g, passed: try passedNames(adding: ["创新创业基础"]))
            #expect(s.remainingRequired == ["创新创业基础"])
            #expect(s.passed["tech"] == true && s.passed["ethnic"] == true && s.passed["ocean"] == true && s.passed["asean"] == true)
            let rows = ElectiveStrategies.strategy(forGrade: g).rows(s)
            #expect(rows.first { $0.id == "ent" }?.value == "2 / 2")
        }
    }
}

@Suite struct HostileInputTests {
    private func decode(_ json: String) throws -> SelectedCourse { try JSONDecoder().decode(SelectedCourse.self, from: Data(json.utf8)) }

    @Test func hugeYearOrTermDoesNotTrapAndIsRejectedOnWrite() async throws {
        let c = try decode(#"{"classId":"a","courseName":"x","credit":1,"year":1e30,"term":-1e30}"#)
        #expect(c.year == 0 && c.term == 0)
        let repo = SelectedCourseRepository(database: try AppDatabase.inMemory(features: [CourseFeature.migrations]))
        await #expect(throws: GxuError.self) { try await repo.replaceAll([c], studentId: "s1") }
        #expect(try await repo.list(studentId: "s1", scope: .all).isEmpty)
    }

    @Test func duplicateClassIdKeepsLastLikeRN() async throws {
        let repo = SelectedCourseRepository(database: try AppDatabase.inMemory(features: [CourseFeature.migrations]))
        func item(_ name: String) -> SelectedCourse { SelectedCourse(classId: "k", courseName: name, credit: 1, year: 2025, term: 1) }
        try await repo.replaceAll([item("OLD"), item("NEW")], studentId: "s1")
        #expect(try await repo.list(studentId: "s1", scope: .all).map(\.courseName) == ["NEW"])
    }

    @Test func invalidCalendarDatesAreNotInvented() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        #expect(DayText.parse("2026-02-30", calendar: cal) == nil)
        #expect(DayText.parse("2026-13-01", calendar: cal) == nil)
        #expect(DayText.parse("2026-00-10", calendar: cal) == nil)
        #expect(DayText.parse("2026-02-28", calendar: cal) != nil)
        let campus = CampusCalendar(timeShift: [], holidays: [HolidayRange(title: "坏", from: "2026-02-30", to: "2026-03-02")])
        let p = HolidayPresentation.build(campus, now: .now, calendar: cal)
        #expect(p.current.isEmpty && p.past.isEmpty)
    }
}

@Suite struct NonFiniteNumberTests {
    @Test func nonFiniteOrHugeCreditsNeverTrapOrBreakCache() async throws {
        func decode(_ credit: String) throws -> SelectedCourse {
            try JSONDecoder().decode(SelectedCourse.self, from: Data(#"{"classId":"a","courseName":"x","credit":\#(credit),"year":2025,"term":1}"#.utf8))
        }
        #expect(try decode(#""NaN""#).credit == 0)
        #expect(try decode(#""inf""#).credit == 0)
        let huge = try decode("1e30")
        #expect(ElectiveStrategy.number(huge.credit) == "1e+30")
        #expect(ElectiveStrategy.number(.infinity) == "0" && ElectiveStrategy.number(.nan) == "0")
        let repo = SelectedCourseRepository(database: try AppDatabase.inMemory(features: [CourseFeature.migrations]))
        try await repo.replaceAll([try decode(#""NaN""#)], studentId: "s1")
        #expect(try await repo.list(studentId: "s1", scope: .all).count == 1)
    }
}
