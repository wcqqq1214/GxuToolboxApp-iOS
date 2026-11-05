import ExamKit
import Foundation
import ScheduleKit

/// 首页和底部附件里“接下来要发生的事”：正在上的课 / 下一节课 / 临近的考试，取最紧的一件。
enum HomeEvent: Equatable {
    case course(CourseOccurrence, isOngoing: Bool, isTomorrow: Bool)
    case exam(ExamItem, isOngoing: Bool)

    var startsAt: Date {
        switch self {
        case .course(let item, _, _): item.startsAt
        case .exam(let item, _): item.date ?? .distantFuture
        }
    }

    var isOngoing: Bool {
        switch self {
        case .course(_, let ongoing, _), .exam(_, let ongoing): ongoing
        }
    }

    /// 正在进行的优先；否则取开始时间更早的。考试比下一节课更早开始才会盖过课程（课程排在前一天不会被远期考试抢占）。
    static func pick(plan: TodayPlan, exams: [ExamItem], now: Date) -> HomeEvent? {
        let ongoingExam = exams.first { ($0.date ?? .distantFuture) <= now }
        if let ongoingExam { return .exam(ongoingExam, isOngoing: true) }
        if let current = plan.current { return .course(current, isOngoing: true, isTomorrow: false) }

        let course = plan.next.map { HomeEvent.course($0, isOngoing: false, isTomorrow: plan.nextIsTomorrow) }
        let exam = exams.first { ($0.date ?? .distantPast) > now }.map { HomeEvent.exam($0, isOngoing: false) }
        switch (course, exam) {
        case let (course?, exam?): return exam.startsAt < course.startsAt ? exam : course
        case let (course?, nil): return course
        case let (nil, exam?): return exam.startsAt.timeIntervalSince(now) < 24 * 3600 ? exam : nil
        case (nil, nil): return nil
        }
    }
}

enum RelativeTime {
    /// "12 分钟后" / "1 小时 5 分钟后" / "明天 08:00" / "11月8日 08:00"
    static func untilStart(_ start: Date, now: Date, calendar: Calendar = .current) -> String {
        let minutes = max(Int(start.timeIntervalSince(now) / 60), 0)
        if calendar.isDate(start, inSameDayAs: now) {
            if minutes < 1 { return "即将开始" }
            if minutes < 60 { return "\(minutes) 分钟后" }
            return minutes % 60 == 0 ? "\(minutes / 60) 小时后" : "\(minutes / 60) 小时 \(minutes % 60) 分钟后"
        }
        let time = clock(start)
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)), calendar.isDate(start, inSameDayAs: tomorrow) {
            return "明天 \(time)"
        }
        return start.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN"))) + " " + time
    }

    /// 文案里是否已经写了具体时刻（如“明天 08:00”“11月8日 08:00”）。相对时间（“12 分钟后”“还剩…”）不含时刻。
    static func showsClock(in text: String) -> Bool { text.contains(":") }

    /// "还剩 25 分钟"
    static func remaining(until end: Date, now: Date) -> String {
        let minutes = max(Int(end.timeIntervalSince(now) / 60), 0)
        if minutes < 1 { return "即将结束" }
        return minutes < 60 ? "还剩 \(minutes) 分钟" : "还剩 \(minutes / 60) 小时 \(minutes % 60) 分钟"
    }

    static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "en_GB")))
    }
}
