import Foundation

/// 考勤图层（RN v2.2 `normalizeAttendanceRecords` + 课表上的状态图标）。考勤数据来自别的模块（FeatureMisc），由 Shell 转成字符串形式注入。
public struct AttendanceMark: Sendable, Hashable {
    /// `yyyy-MM-dd` 或 `yyyy-M-d`
    public var date: String
    /// 节次范围，如 `1,2`
    public var periodRange: String
    /// 考勤系统的状态码：1 正常、2 迟到、4 缺勤、5 未开始、100 无需打卡
    public var statusCode: Int?

    public init(date: String, periodRange: String, statusCode: Int?) {
        self.date = date
        self.periodRange = periodRange
        self.statusCode = statusCode
    }
}

public enum AttendanceStatus: Sendable, Hashable {
    case normal, late, absent, notStarted, noNeed

    init?(code: Int?) {
        switch code {
        case 1: self = .normal
        case 2: self = .late
        case 4: self = .absent
        case 5: self = .notStarted
        case 100: self = .noNeed
        default: return nil
        }
    }

    public var label: String {
        switch self {
        case .normal: "考勤正常"
        case .late: "迟到"
        case .absent: "缺勤"
        case .notStarted: "考勤未开始"
        case .noNeed: "无需打卡"
        }
    }
}

/// 按“日期 + 起止节次”对上课程。无效日期 / 节次（不是 1–13 的整数、止早于起）的记录不参与；同一键有多条时以后出现的为准
public struct AttendanceIndex: Sendable {
    private struct Key: Hashable { var day: Date; var begin: Int; var end: Int }
    private var statuses: [Key: AttendanceStatus] = [:]
    public let calendar: Calendar

    public init(_ marks: [AttendanceMark], calendar: Calendar) {
        self.calendar = calendar
        for mark in marks {
            guard
                let day = Self.parse(mark.date, calendar: calendar), let (begin, end) = Self.periods(mark.periodRange),
                let status = AttendanceStatus(code: mark.statusCode)
            else { continue }
            statuses[Key(day: day, begin: begin, end: end)] = status
        }
    }

    public var isEmpty: Bool { statuses.isEmpty }

    public func status(for occurrence: CourseOccurrence) -> AttendanceStatus? {
        guard !occurrence.course.isCustom else { return nil }
        return statuses[Key(day: calendar.startOfDay(for: occurrence.date), begin: occurrence.course.begin, end: occurrence.course.end)]
    }

    static func periods(_ text: String) -> (Int, Int)? {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        let numbers = parts.compactMap { part in part.allSatisfy(\.isASCII) && part.allSatisfy(\.isNumber) ? Int(part) : nil }
        guard !parts.isEmpty, numbers.count == parts.count, numbers.allSatisfy({ (1...13).contains($0) }),
              let first = numbers.first, let last = numbers.last, last >= first else { return nil }
        return (first, last)
    }

    static func parse(_ text: String, calendar: Calendar) -> Date? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.count == 3, let y = parts[0], let m = parts[1], let d = parts[2] else { return nil }
        let gregorian = calendar.gregorianEquivalent
        guard let date = gregorian.date(from: DateComponents(year: y, month: m, day: d)) else { return nil }
        let back = gregorian.dateComponents([.year, .month, .day], from: date)
        guard back.year == y, back.month == m, back.day == d else { return nil }   // 2026-02-30 之类不顺延
        return gregorian.startOfDay(for: date)
    }
}
