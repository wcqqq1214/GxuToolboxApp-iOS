import Foundation
import GxuFoundation
import Testing
@testable import ScheduleKit

struct GridExamTests {
    private func exam(_ id: String, _ start: String, _ end: String) -> GridExam {
        GridExam(id: id, title: id, start: at(start), end: at(end))
    }

    @Test func periodsFollowRNRule() throws {
        let a = try #require(ExamPlacement.periods(start: at("2026-09-07 09:00"), end: at("2026-09-07 11:00"), calendar: shanghai))
        #expect(a.begin == 2 && a.end == 4)
        let b = try #require(ExamPlacement.periods(start: at("2026-09-07 08:00"), end: at("2026-09-07 09:40"), calendar: shanghai))
        #expect(b.begin == 1 && b.end == 2)
        let c = try #require(ExamPlacement.periods(start: at("2026-09-07 14:30"), end: at("2026-09-07 16:30"), calendar: shanghai))
        #expect(c.begin == 5 && c.end == 7)
        #expect(ExamPlacement.periods(start: at("2026-09-07 22:30"), end: at("2026-09-07 23:30"), calendar: shanghai) == nil)
    }

    @Test func blocksLandOnTheirDateAndDropOutOfTermOnes() {
        let inTerm = exam("期中", "2026-09-16 09:00", "2026-09-16 11:00")
        let before = exam("早了", "2026-09-01 09:00", "2026-09-01 11:00")
        let after = exam("晚了", "2027-03-01 09:00", "2027-03-01 11:00")
        let blocks = ExamPlacement.blocks(for: [after, inTerm, before], term: term)
        #expect(blocks.map(\.id) == ["期中"])
        #expect(blocks[0].week == 2 && blocks[0].weekday == 3 && blocks[0].begin == 2 && blocks[0].end == 4)
    }

    @Test func indexExposesExamsByWeekAndDay() {
        let blocks = ExamPlacement.blocks(for: [exam("A", "2026-09-16 09:00", "2026-09-16 11:00")], term: term)
        let index = ScheduleIndex(occurrences: [], examBlocks: blocks)
        #expect(index.examBlocks(inWeek: 2, weekday: 3).count == 1)
        #expect(index.examBlocks(inWeek: 2, weekday: 4).isEmpty)
        #expect(index.examBlocks(inWeek: 3, weekday: 3).isEmpty)
    }
}

struct RelatedExamsTests {
    private let t1 = AcademicTerm(year: 2026, term: 1)
    private let t0 = AcademicTerm(year: 2025, term: 2)

    private func exam(_ title: String, _ start: String, _ end: String, term: AcademicTerm? = AcademicTerm(year: 2026, term: 1)) -> GridExam {
        GridExam(id: title + start, title: title, start: at(start), end: at(end), term: term)
    }

    @Test func matchesByNameSortedByStart() {
        let exams = [exam("高等数学", "2026-12-20 09:00", "2026-12-20 11:00"), exam("大学英语", "2026-12-18 09:00", "2026-12-18 11:00"), exam("高等数学", "2026-11-10 09:00", "2026-11-10 11:00")]
        #expect(RelatedExams.matching(courseName: " 高等数学", in: exams, term: t1).map(\.start) == [at("2026-11-10 09:00"), at("2026-12-20 09:00")])
        #expect(RelatedExams.matching(courseName: "", in: exams, term: t1).isEmpty)
    }

    @Test func badgeStates() {
        let e = exam("高等数学", "2026-11-08 09:00", "2026-11-08 11:00")
        #expect(RelatedExams.badge(for: e, now: at("2026-11-06 10:00"), calendar: shanghai) == "2 天后")
        #expect(RelatedExams.badge(for: e, now: at("2026-11-08 07:00"), calendar: shanghai) == "今天考试")
        #expect(RelatedExams.badge(for: e, now: at("2026-11-08 12:00"), calendar: shanghai) == "已结束")
    }
}

extension RelatedExamsTests {
    @Test func sameNamedCourseOnlyShowsTheViewedTerm() {
        let exams = [
            exam("高等数学", "2026-06-20 09:00", "2026-06-20 11:00", term: t0),
            exam("高等数学", "2026-12-20 09:00", "2026-12-20 11:00"),
        ]
        #expect(RelatedExams.matching(courseName: "高等数学", in: exams, term: t1).map(\.start) == [at("2026-12-20 09:00")])
        #expect(RelatedExams.matching(courseName: "高等数学", in: exams, term: t0).map(\.start) == [at("2026-06-20 09:00")])
    }

    @Test func termWithoutRelatedExamsIsEmpty() {
        let exams = [exam("高等数学", "2026-06-20 09:00", "2026-06-20 11:00", term: t0)]
        #expect(RelatedExams.matching(courseName: "高等数学", in: exams, term: t1).isEmpty)
    }

    @Test func examsWithoutSourceTermAreNotGuessedByDate() {
        let exams = [exam("高等数学", "2026-12-20 09:00", "2026-12-20 11:00", term: nil)]
        #expect(RelatedExams.matching(courseName: "高等数学", in: exams, term: t1).isEmpty)
        #expect(RelatedExams.matching(courseName: "高等数学", in: exams, term: nil).isEmpty)
    }
}
