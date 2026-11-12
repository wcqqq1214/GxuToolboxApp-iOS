import ExamKit
import Foundation
import ScheduleKit

enum HomeEvent: Equatable {
    case course(CourseOccurrence, isOngoing: Bool)
    case exam(ExamItem, isOngoing: Bool)
    case holiday(NextHoliday)

    static let holidayNoticeDays = 7

    var startsAt: Date {
        switch self {
        case .course(let item, _): item.startsAt
        case .exam(let item, _): item.date ?? .distantFuture
        case .holiday(let holiday): holiday.startsAt
        }
    }

    var isOngoing: Bool {
        switch self {
        case .course(_, let ongoing), .exam(_, let ongoing): ongoing
        case .holiday(let holiday): holiday.isOngoing
        }
    }

    static func pick(snapshot: ScheduleSnapshot?, campus: CampusCalendar? = nil, exams: [ExamItem], now: Date, calendar: Calendar = .current) -> HomeEvent? {
        let calendar = snapshot?.termCalendar.calendar ?? calendar
        let holidays = (campus ?? snapshot?.campus ?? .empty).holidays
        let holiday = NextHoliday.next(holidays: holidays, calendar: calendar, now: now)
        let plan = snapshot?.todayPlan(now: now)
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-GxuPickEvent"), i + 1 < args.count {
            switch args[i + 1] {
            case "holiday": return holiday.map(HomeEvent.holiday)
            case "exam": return exams.first { ($0.date ?? .distantPast) > now }.map { .exam($0, isOngoing: false) }
            default: return pick(plan: plan, exams: [], now: now, calendar: calendar)
            }
        }
        #endif
        return pick(plan: plan, exams: exams, holiday: holiday, now: now, calendar: calendar)
    }

    static func pick(plan: TodayPlan?, exams: [ExamItem], holiday: NextHoliday? = nil, now: Date, calendar: Calendar = .current) -> HomeEvent? {
        let ongoingExam = exams.first { exam in
            guard let start = exam.date, let end = exam.endsAt else { return false }
            return start <= now && now < end
        }
        if let ongoingExam { return .exam(ongoingExam, isOngoing: true) }
        if let current = plan?.current { return .course(current, isOngoing: true) }

        let course = plan?.next.map { HomeEvent.course($0, isOngoing: false) }
        let exam = exams.first { ($0.date ?? .distantPast) > now }.map { HomeEvent.exam($0, isOngoing: false) }
        let base: HomeEvent?
        switch (course, exam) {
        case let (course?, exam?): base = exam.startsAt < course.startsAt ? exam : course
        case let (course?, nil): base = course
        case let (nil, exam?): base = exam.startsAt.timeIntervalSince(now) < 24 * 3600 ? exam : nil
        case (nil, nil): base = nil
        }
        guard let holiday else { return base }
        if holiday.isOngoing { return .holiday(holiday) }
        guard let daysUntilHoliday = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: holiday.date)).day,
              (0...holidayNoticeDays).contains(daysUntilHoliday) else { return base }
        guard let base else { return .holiday(holiday) }
        return holiday.startsAt <= base.startsAt ? .holiday(holiday) : base
    }
}

enum RelativeTime {
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

    static func showsClock(in text: String) -> Bool { text.contains(":") }

    static func remaining(until end: Date, now: Date) -> String {
        let minutes = max(Int(end.timeIntervalSince(now) / 60), 0)
        if minutes < 1 { return "即将结束" }
        return minutes < 60 ? "还剩 \(minutes) 分钟" : "还剩 \(minutes / 60) 小时 \(minutes % 60) 分钟"
    }

    static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "en_GB")))
    }
}
