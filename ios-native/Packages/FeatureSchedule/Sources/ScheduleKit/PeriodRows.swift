import Foundation

/// 课表网格的“显示行”。纯显示层的合并：第 9、10 节（作息时间重叠）合成一行“9-10 节”，其余一节一行，共 12 行。
/// `ClassPeriods` 的 13 节数据、接口节次、冲突 / 今日计划等计算逻辑都不受影响；只有画网格时用行号定位。
public enum PeriodRows {
    public struct Row: Sendable, Hashable {
        /// 1-based 行号
        public let index: Int
        /// 这一行包含的第一节 / 最后一节
        public let first: Int
        public let last: Int
        public var isMerged: Bool { first != last }
        /// 左侧时间列的节次文案：“3” 或 “9 - 10”（和 RN 的 `N - M` 写法一致）
        public var label: String { isMerged ? "\(first) - \(last)" : "\(first)" }
        /// 上课 / 下课时间（取这一行第一节的开始、最后一节的结束）
        public var startText: String { ClassPeriods.period(first)?.startText ?? "" }
        public var endText: String { ClassPeriods.period(last)?.endText ?? "" }
        var startMinutes: Double { ClassPeriods.period(first).map { Double($0.start.hour * 60 + $0.start.minute) } ?? 0 }
        var endMinutes: Double { ClassPeriods.period(last).map { Double($0.end.hour * 60 + $0.end.minute) } ?? 0 }
    }

    public static let all: [Row] = {
        var rows: [Row] = []
        var period = 1
        while period <= ClassPeriods.count {
            // 第 9、10 节合并
            let last = period == 9 ? 10 : period
            rows.append(Row(index: rows.count + 1, first: period, last: last))
            period = last + 1
        }
        return rows
    }()

    public static var count: Int { all.count }

    /// 某一节所在的行（1-based）。越界的节次夹到首 / 末行。
    public static func row(ofPeriod period: Int) -> Int {
        all.first { (period >= $0.first && period <= $0.last) }?.index ?? (period < 1 ? 1 : count)
    }

    /// 一段节次（`begin...end`）占用的行区间
    public static func rows(begin: Int, end: Int) -> ClosedRange<Int> {
        row(ofPeriod: begin)...max(row(ofPeriod: begin), row(ofPeriod: end))
    }

    /// 把时刻映射到网格里的位置：0 = 第 1 行上沿，12 = 最后一行下沿；行内按分钟线性插值，课间停在上一行下沿。
    public static func position(at date: Date, calendar: Calendar = .current) -> Double {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let minutes = Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) + Double(c.second ?? 0) / 60
        guard let index = all.lastIndex(where: { $0.startMinutes <= minutes }) else { return 0 }
        let row = all[index]
        if minutes >= row.endMinutes { return Double(index + 1) }
        return Double(index) + (minutes - row.startMinutes) / (row.endMinutes - row.startMinutes)
    }
}
