import Foundation

public struct TodayPlan: Sendable, Equatable {
    public enum DayNote: Sendable, Equatable {
        case holiday(String)
        case rest
        case makeup(from: Date)
    }

    public enum Phase: Sendable, Equatable {
        case beforeTerm(daysUntilStart: Int)
        case inTerm
        case afterTerm
    }

    public let phase: Phase
    public let date: Date
    public let week: Int?
    public let weekday: Int
    public let note: DayNote?
    public let courses: [CourseOccurrence]
    public let current: CourseOccurrence?
    public let next: CourseOccurrence?
    public let nextIsTomorrow: Bool
    public let tomorrow: [CourseOccurrence]

    public func status(of course: CourseOccurrence, now: Date) -> CourseStatus {
        if course.endsAt <= now { return .finished }
        if course.startsAt <= now { return .ongoing }
        return .upcoming
    }

    public enum CourseStatus: Sendable { case finished, ongoing, upcoming }

    public static func make(
        occurrences: [CourseOccurrence], dayBlocks: [DayBlock], term: TermCalendar, choices: [String: String] = [:], now: Date
    ) -> TodayPlan {
        let calendar = term.calendar
        let today = calendar.startOfDay(for: now)
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let week = term.week(containing: today)

        let phase: Phase
        if week < 1 {
            phase = .beforeTerm(daysUntilStart: calendar.dateComponents([.day], from: today, to: term.startDate).day ?? 0)
        } else if week > term.weekCount {
            phase = .afterTerm
        } else {
            phase = .inTerm
        }

        let resolved = ConflictResolver.resolve(occurrences, choices: choices)
        let courses = resolved.filter { $0.date == today }
        let tomorrow = resolved.filter { $0.date == tomorrowDate }

        let note: DayNote?
        if let block = dayBlocks.first(where: { $0.date == today }) {
            switch block.kind {
            case .holiday: note = .holiday(block.title)
            case .rest: note = .rest
            }
        } else if let moved = courses.first(where: \.isMakeup), let from = moved.shiftedFrom {
            note = .makeup(from: from)
        } else {
            note = nil
        }

        let current = courses.first { $0.startsAt <= now && now < $0.endsAt }
        let todayNext = courses.first { $0.startsAt > now }
        return TodayPlan(
            phase: phase, date: today, week: phase == .inTerm ? week : nil, weekday: term.weekday(of: today),
            note: note, courses: courses, current: current,
            next: todayNext ?? tomorrow.first, nextIsTomorrow: todayNext == nil && !tomorrow.isEmpty, tomorrow: tomorrow
        )
    }
}
