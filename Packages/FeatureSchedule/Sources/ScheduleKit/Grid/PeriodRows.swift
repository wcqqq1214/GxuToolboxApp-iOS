import Foundation

public enum PeriodRows {
    public struct Row: Sendable, Hashable {
        public let index: Int
        public let first: Int
        public let last: Int
        public var isMerged: Bool { first != last }
        public var label: String { isMerged ? "\(first) - \(last)" : "\(first)" }
        public var startText: String { ClassPeriods.period(first)?.startText ?? "" }
        public var endText: String { ClassPeriods.period(last)?.endText ?? "" }
        var startMinutes: Double { ClassPeriods.period(first).map { Double($0.start.hour * 60 + $0.start.minute) } ?? 0 }
        var endMinutes: Double { ClassPeriods.period(last).map { Double($0.end.hour * 60 + $0.end.minute) } ?? 0 }
    }

    public static let all: [Row] = {
        var rows: [Row] = []
        var period = 1
        while period <= ClassPeriods.count {
            let last = period == 9 ? 10 : period
            rows.append(Row(index: rows.count + 1, first: period, last: last))
            period = last + 1
        }
        return rows
    }()

    public static var count: Int { all.count }

    public static func row(ofPeriod period: Int) -> Int {
        all.first { (period >= $0.first && period <= $0.last) }?.index ?? (period < 1 ? 1 : count)
    }

    public static func rows(begin: Int, end: Int) -> ClosedRange<Int> {
        row(ofPeriod: begin)...max(row(ofPeriod: begin), row(ofPeriod: end))
    }

    public static func position(at date: Date, calendar: Calendar = .current) -> Double {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let minutes = Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) + Double(c.second ?? 0) / 60
        guard let index = all.lastIndex(where: { $0.startMinutes <= minutes }) else { return 0 }
        let row = all[index]
        if minutes >= row.endMinutes { return Double(index + 1) }
        return Double(index) + (minutes - row.startMinutes) / (row.endMinutes - row.startMinutes)
    }
}
