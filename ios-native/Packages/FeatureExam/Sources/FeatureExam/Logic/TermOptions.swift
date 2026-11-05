import Foundation
import GxuFoundation

/// 学期选择器的候选项与默认值（移植自 RN `ChooseTerm`）。
public enum TermOptions {
    /// 当前学年：9 月之前算上一年
    public static func academicYear(now: Date = .now, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month], from: now)
        return (c.month ?? 1) < 9 ? (c.year ?? 0) - 1 : (c.year ?? 0)
    }

    /// 入学年份起 `studyYears` 个学年，且不晚于当前学年。入学年份未知时取最近 `studyYears` 个学年
    public static func years(enrollmentYear: Int?, studyYears: Int = 4, now: Date = .now, calendar: Calendar = .current) -> [Int] {
        let current = academicYear(now: now, calendar: calendar)
        let first = enrollmentYear ?? (current - studyYears + 1)
        return (0..<max(studyYears, 1)).map { first + $0 }.filter { $0 <= current }
    }

    /// 单步回退一个学期：春(2) → 同年秋(1)，秋(1) → 上一年春(2)
    public static func previous(_ term: AcademicTerm) -> AcademicTerm {
        term.term == 2 ? AcademicTerm(year: term.year, term: 1) : AcademicTerm(year: term.year - 1, term: 2)
    }

    // TEMP(coord-2): B 的 ScheduleKit 提供 currentTerm / isStarted 后改用开学日。
    // 目前按月份推断：9–1 月为秋季，2–8 月为春季；暑假默认落在刚结束的春季学期
    public static func defaultTerm(now: Date = .now, calendar: Calendar = .current) -> AcademicTerm {
        let month = calendar.component(.month, from: now)
        let year = academicYear(now: now, calendar: calendar)
        return AcademicTerm(year: year, term: (month >= 9 || month == 1) ? 1 : 2)
    }
}
