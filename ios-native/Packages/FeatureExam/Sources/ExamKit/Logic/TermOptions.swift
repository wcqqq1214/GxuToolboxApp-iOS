import Foundation
import GxuAuth
import GxuFoundation
import ScheduleKit

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

    /// 开学日数据不可用（离线且无缓存、或解析失败）时按月份推断：9–1 月为秋季，2–8 月为春季；
    /// 暑假默认落在刚结束的春季学期
    public static func defaultTerm(now: Date = .now, calendar: Calendar = .current) -> AcademicTerm {
        let month = calendar.component(.month, from: now)
        let year = academicYear(now: now, calendar: calendar)
        return AcademicTerm(year: year, term: (month >= 9 || month == 1) ? 1 : 2)
    }

    /// 默认学期（RN `ChooseTerm`）：已开学看当前学期；假期看刚结束的学期，
    /// 但回退后早于入学年份（如大一开学前的暑假）则看当前学期。
    /// `current` 为 nil（拿不到开学日）或是小学期时，退回按月份推断。
    public static func initialTerm(
        current: AcademicTerm?, isStarted: Bool, enrollmentYear: Int? = nil,
        now: Date = .now, calendar: Calendar = .current
    ) -> AcademicTerm {
        guard let current, current.term == 1 || current.term == 2 else {
            return defaultTerm(now: now, calendar: calendar)
        }
        if isStarted { return current }
        let prev = previous(current)
        if let enrollmentYear, prev.year < enrollmentYear { return current }
        return prev
    }
}

/// 学期选择器的上下文：默认学期 + 可选学年范围
public struct TermContext: Equatable, Sendable {
    public var term: AcademicTerm
    public var years: [Int]
}

/// 取当前学期（B 的 ScheduleKit，优先缓存）和用户资料（A 的 `services.profiles`，优先缓存），
/// 套用 `TermOptions.initialTerm` / `years`。两者任一拿不到都有退路（月份推断、最近 4 个学年）
@MainActor
public func resolveTermContext(services: AppServices) async -> TermContext {
    async let info = ScheduleRepository(backend: services.backend, database: services.database).currentTermInfo()
    let profile: UserProfile?
    if let studentId = services.accounts.studentId {
        profile = try? await services.profiles.profile(studentId: studentId)
    } else {
        profile = nil
    }
    let current = await info
    return TermContext(
        term: TermOptions.initialTerm(current: current?.term, isStarted: current?.isStarted ?? true, enrollmentYear: profile?.enrollmentYear),
        years: TermOptions.years(enrollmentYear: profile?.enrollmentYear, studyYears: profile?.studyYears ?? 4)
    )
}
