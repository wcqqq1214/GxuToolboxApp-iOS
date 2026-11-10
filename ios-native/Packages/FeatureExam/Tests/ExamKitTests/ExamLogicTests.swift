import Foundation
import Testing
import GxuFoundation
@testable import ExamKit

private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return c
}()

private func at(_ s: String) -> Date {
    let f = DateFormatter()
    f.calendar = calendar
    f.timeZone = calendar.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}

@Suite struct GpaFormatTests {
    @Test func twoDecimalsRoundHalfUp() {
        #expect(GpaCalculator.format(2.05) == "2.05")
        #expect(GpaCalculator.format(3.765) == "3.77")
        #expect(GpaCalculator.format(3.7649) == "3.76")
        #expect(GpaCalculator.format(2.0) == "2.00")
        #expect(GpaCalculator.format(0) == "0.00")
        #expect(GpaCalculator.format(.nan) == "N/A")
        #expect(GpaCalculator.format(80.125) == "80.13")
        // 总绩点 (4.0×2 + 3.5×3) / 5 = 3.7；加权平均 (90×2 + 85×3) / 5 = 87
        let r = GpaCalculator.calculate([Score(id: "a", year: 2025, term: 1, courseName: "a", credit: 2, score: 90), Score(id: "b", year: 2025, term: 1, courseName: "b", credit: 3, score: 85)])
        #expect(GpaCalculator.format(r.gpa) == "3.70" && GpaCalculator.format(r.wam) == "87.00")
    }
}

@Suite struct ExamTimeParserTests {
    let time = "2026-07-15(09:00-11:00)"

    @Test func beforeDuringAfterExam() {
        let before = ExamTimeParser.parse(time, now: at("2026-07-14 20:00"), calendar: calendar)
        #expect(before.status == .upcoming)
        #expect(before.date == at("2026-07-15 09:00"))
        #expect(ExamTimeParser.parse(time, now: at("2026-07-15 10:00"), calendar: calendar).status == .upcoming)
        #expect(ExamTimeParser.parse(time, now: at("2026-07-15 11:01"), calendar: calendar).status == .past)
    }

    @Test func endingExactlyNowIsStillUpcoming() {
        #expect(ExamTimeParser.parse(time, now: at("2026-07-15 11:00"), calendar: calendar).status == .upcoming)
    }

    @Test(arguments: ["", "待定", "2026-07-15", "2026-07-15 09:00-11:00", "2026-07-15(0900-1100)"])
    func malformedIsTbd(_ s: String) {
        let r = ExamTimeParser.parse(s, now: at("2026-07-14 20:00"), calendar: calendar)
        #expect(r.status == .tbd)
        #expect(r.date == nil)
    }

    /// 与 RN 有意不同：dayjs 会滚动进位，这里判 tbd
    @Test(arguments: ["2026-02-30(09:00-11:00)", "2026-13-01(09:00-11:00)", "2026-07-15(25:00-26:00)"])
    func outOfRangeIsTbd(_ s: String) {
        #expect(ExamTimeParser.parse(s, now: at("2026-07-14 20:00"), calendar: calendar).status == .tbd)
    }
}

@Suite struct ExamSortingTests {
    let now = at("2026-07-10 12:00")

    private func item(_ id: String, _ time: String) -> ExamItem {
        ExamItem(Exam(id: id, course: id, classroom: "", time: time, type: ""), now: now, calendar: calendar)
    }

    @Test func orderAndSections() {
        let items = [
            item("past-early", "2026-07-01(09:00-11:00)"),
            item("up-late", "2026-07-20(09:00-11:00)"),
            item("tbd", ""),
            item("past-late", "2026-07-09(09:00-11:00)"),
            item("up-early", "2026-07-12(15:00-17:00)"),
        ]
        #expect(ExamSorting.sorted(items).map(\.id) == ["up-early", "up-late", "tbd", "past-late", "past-early"])
        let sections = ExamSorting.sections(items)
        #expect(sections.upcoming.map(\.id) == ["up-early", "up-late", "tbd"])
        #expect(sections.past.map(\.id) == ["past-late", "past-early"])
    }

    @Test func tiesKeepInputOrder() {
        let items = [item("a", ""), item("b", ""), item("c", "")]
        #expect(ExamSorting.sorted(items).map(\.id) == ["a", "b", "c"])
    }

    @Test func countdown() {
        let t = at("2026-07-10 23:30")
        #expect(item("x", "2026-07-10(23:50-23:59)").countdownText(now: t, calendar: calendar) == "今日开考")
        #expect(item("x", "2026-07-11(00:10-02:00)").countdownText(now: t, calendar: calendar) == "明日开考")
        #expect(item("x", "2026-07-15(09:00-11:00)").countdownText(now: t, calendar: calendar) == "5天后")
        #expect(item("x", "2026-07-01(09:00-11:00)").countdownText(now: t, calendar: calendar) == nil)
        #expect(item("x", "").countdownText(now: t, calendar: calendar) == nil)
    }
}

@Suite struct GpaTests {
    private func s(_ score: Double?, _ credit: Double?) -> Score {
        Score(id: UUID().uuidString, year: 2025, term: 1, courseName: "c", credit: credit, score: score)
    }

    /// 期望值由 RN `useGpa` 的同一公式在 node 里算出
    @Test func mixedPassAndFail() {
        let r = GpaCalculator.calculate([s(90, 3), s(75, 2), s(59, 1), s(60, 2)])
        #expect(r.gpa == 2.375)
        #expect(r.wam == 74.875)
    }

    @Test func allFailKeepsWam() {
        let r = GpaCalculator.calculate([s(50, 2), s(40, 3)])
        #expect(r.gpa == 0)
        #expect(r.wam == 44)
    }

    @Test func fractionalCredits() {
        let r = GpaCalculator.calculate([s(88, 3.5), s(92.5, 2.5), s(61, 0.5)])
        #expect(abs(r.gpa - 3.765384615384616) < 1e-12)
        #expect(abs(r.wam - 87.65384615384616) < 1e-12)
    }

    @Test func emptyAndZeroCredit() {
        #expect(GpaCalculator.calculate([]) == .zero)
        #expect(GpaCalculator.calculate([s(90, 0)]) == .zero)
    }

    /// 与 RN 不同：RN 会算出 NaN
    @Test func unparsableEntriesAreSkipped() {
        let r = GpaCalculator.calculate([s(nil, 2), s(80, nil), s(90, 3)])
        #expect(r.gpa == 4)
        #expect(r.wam == 90)
    }

    @Test func pointText() {
        #expect(GpaCalculator.pointText(for: nil) == "N/A")
        #expect(GpaCalculator.pointText(for: 59) == "0")
        #expect(GpaCalculator.pointText(for: 59.5) == "0")
        #expect(GpaCalculator.pointText(for: 60) == "1.00")
        #expect(GpaCalculator.pointText(for: 72.5) == "2.25")
        #expect(GpaCalculator.pointText(for: 85) == "3.50")
        #expect(GpaCalculator.pointText(for: 87.65) == "3.77")
        #expect(GpaCalculator.pointText(for: 100) == "5.00")
        #expect(GpaCalculator.pointText(for: 70.5) == "2.05")
    }
}

@Suite struct TermOptionsTests {
    private let autumn = AcademicTerm(year: 2026, term: 1)

    @Test func startedUsesCurrent() {
        #expect(TermOptions.initialTerm(current: autumn, isStarted: true, now: at("2026-10-01 12:00"), calendar: calendar) == autumn)
    }

    /// 假期：B 的 current 指向即将开始的学期，默认看刚结束的那个
    @Test func vacationUsesPrevious() {
        #expect(TermOptions.initialTerm(current: autumn, isStarted: false, now: at("2026-08-20 12:00"), calendar: calendar)
            == AcademicTerm(year: 2025, term: 2))
        #expect(TermOptions.initialTerm(current: AcademicTerm(year: 2026, term: 2), isStarted: false, now: at("2027-01-20 12:00"), calendar: calendar)
            == AcademicTerm(year: 2026, term: 1))
    }

    @Test func vacationBeforeEnrollmentFallsBackToCurrent() {
        #expect(TermOptions.initialTerm(current: autumn, isStarted: false, enrollmentYear: 2026, now: at("2026-08-20 12:00"), calendar: calendar) == autumn)
        #expect(TermOptions.initialTerm(current: autumn, isStarted: false, enrollmentYear: 2025, now: at("2026-08-20 12:00"), calendar: calendar)
            == AcademicTerm(year: 2025, term: 2))
    }

    @Test func missingOrSummerTermFallsBackToMonth() {
        #expect(TermOptions.initialTerm(current: nil, isStarted: true, now: at("2026-11-05 12:00"), calendar: calendar) == autumn)
        #expect(TermOptions.initialTerm(current: nil, isStarted: true, now: at("2026-03-05 12:00"), calendar: calendar) == AcademicTerm(year: 2025, term: 2))
        #expect(TermOptions.initialTerm(current: nil, isStarted: true, now: at("2026-07-05 12:00"), calendar: calendar) == AcademicTerm(year: 2025, term: 2))
        #expect(TermOptions.initialTerm(current: AcademicTerm(year: 2025, term: 3), isStarted: true, now: at("2026-01-05 12:00"), calendar: calendar) == AcademicTerm(year: 2025, term: 1))
    }

    @Test func yearsRespectEnrollmentAndCurrentYear() {
        let now = at("2026-11-05 12:00")
        #expect(TermOptions.years(enrollmentYear: 2024, studyYears: 4, now: now, calendar: calendar) == [2024, 2025, 2026])
        #expect(TermOptions.years(enrollmentYear: nil, studyYears: 4, now: now, calendar: calendar) == [2023, 2024, 2025, 2026])
    }

    @Test func yearsFollowStudyYearsAndNeverExceedCurrent() {
        let now = at("2026-11-05 12:00")
        #expect(TermOptions.years(enrollmentYear: 2022, studyYears: 4, now: now, calendar: calendar) == [2022, 2023, 2024, 2025])
        #expect(TermOptions.years(enrollmentYear: 2022, studyYears: 5, now: now, calendar: calendar) == [2022, 2023, 2024, 2025, 2026])
        #expect(TermOptions.years(enrollmentYear: 2030, studyYears: 4, now: now, calendar: calendar).isEmpty)
        // 3 月仍属上一学年
        #expect(TermOptions.years(enrollmentYear: 2023, studyYears: 4, now: at("2026-03-05 12:00"), calendar: calendar) == [2023, 2024, 2025])
    }
}
