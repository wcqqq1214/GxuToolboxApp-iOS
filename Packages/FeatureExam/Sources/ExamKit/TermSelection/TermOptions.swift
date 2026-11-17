import Foundation
import GxuAuth
import GxuFoundation
import ScheduleKit

public enum TermOptions {
    public static func academicYear(now: Date = .now, calendar: Calendar = .current) -> Int {
        let calendar = calendar.gregorianEquivalent
        let c = calendar.dateComponents([.year, .month], from: now)
        return (c.month ?? 1) < 9 ? (c.year ?? 0) - 1 : (c.year ?? 0)
    }

    public static func years(enrollmentYear: Int?, studyYears: Int = 4, studentId: String? = nil, now: Date = .now, calendar: Calendar = .current) -> [Int] {
        let current = academicYear(now: now, calendar: calendar)
        let profileStart = enrollmentYear ?? (current - studyYears + 1)
        let first = enrollmentYear.map { min($0, enrollmentYearFromStudentId(studentId) ?? $0) } ?? profileStart
        let last = min(profileStart + max(studyYears, 1) - 1, current)
        return first <= last ? Array(first...last) : []
    }

    private static func enrollmentYearFromStudentId(_ studentId: String?) -> Int? {
        guard let studentId, studentId.utf8.count == 10, studentId.utf8.allSatisfy({ (48...57).contains($0) }),
              let suffix = Int(studentId.prefix(2)) else { return nil }
        return 2000 + suffix
    }

    public static func previous(_ term: AcademicTerm) -> AcademicTerm {
        term.term == 2 ? AcademicTerm(year: term.year, term: 1) : AcademicTerm(year: term.year - 1, term: 2)
    }

    public static func defaultTerm(now: Date = .now, calendar: Calendar = .current) -> AcademicTerm {
        let calendar = calendar.gregorianEquivalent
        let month = calendar.component(.month, from: now)
        let year = academicYear(now: now, calendar: calendar)
        return AcademicTerm(year: year, term: (month >= 9 || month == 1) ? 1 : 2)
    }

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

public struct TermContext: Equatable, Sendable {
    public var term: AcademicTerm
    public var years: [Int]
}

@MainActor
public func resolveTermContext(services: AppServices) async -> TermContext {
    async let info = ScheduleRepository(backend: services.backend, database: services.database).currentTermInfo()
    let studentId = services.accounts.studentId
    let profile: UserProfile?
    if let studentId {
        profile = try? await services.profiles.profile(studentId: studentId)
    } else {
        profile = nil
    }
    let current = await info
    return TermContext(
        term: TermOptions.initialTerm(current: current?.term, isStarted: current?.isStarted ?? true, enrollmentYear: profile?.enrollmentYear),
        years: TermOptions.years(enrollmentYear: profile?.enrollmentYear, studyYears: profile?.studyYears ?? 4, studentId: studentId)
    )
}
