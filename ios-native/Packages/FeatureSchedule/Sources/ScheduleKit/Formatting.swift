import Foundation

public enum WeekFormatter {
    /// `[1,2,3,4,6,8,9]` → "1-4、6、8-9周"；整组同奇偶且间隔为 2（≥3 项）→ "1-15周(单)"
    public static func describe(_ weeks: [Int]) -> String {
        let sorted = Array(Set(weeks)).sorted()
        guard !sorted.isEmpty else { return "" }
        if sorted.count >= 3, sorted.adjacentPairs().allSatisfy({ $1 - $0 == 2 }) {
            return "\(sorted[0])-\(sorted[sorted.count - 1])周(\(sorted[0] % 2 == 1 ? "单" : "双"))"
        }
        var parts: [String] = []
        var start = sorted[0], previous = sorted[0]
        func flush() { parts.append(start == previous ? "\(start)" : "\(start)-\(previous)") }
        for week in sorted.dropFirst() {
            if week == previous + 1 { previous = week; continue }
            flush()
            start = week
            previous = week
        }
        flush()
        return parts.joined(separator: "、") + "周"
    }
}

private extension Array {
    func adjacentPairs() -> [(Element, Element)] { Array<(Element, Element)>(zip(self, dropFirst())) }
}

public enum LocationFormatter {
    /// 楼号 + 教室。体育学院的课只保留“北 / 西 / 东”及之后的部分（如 “体育学院西体育馆” → “西体育馆”）。
    public static func display(building: String, venue: String) -> String {
        let full = building + venue
        guard full.contains("体育学院"), let index = full.firstIndex(where: { "北西东".contains($0) }) else { return full }
        return String(full[index...])
    }

    /// 课程块里的短地点：教室号（`西3-406` → `西3\n406`，窄列里按 “-” 换行）
    public static func blockText(venue: String, singleLine: Bool) -> String {
        singleLine ? venue : venue.replacingOccurrences(of: "-", with: "\n")
    }
}

public extension ClassPeriods {
    /// 把时刻映射到网格里的位置：0 = 第 1 节上沿，13 = 第 13 节下沿；节内按分钟线性插值，课间停在上一节下沿。
    /// 第 9 / 10 节作息重叠时以后开始的那节为准。
    static func position(at date: Date, calendar: Calendar = .current) -> Double {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let minutes = Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) + Double(c.second ?? 0) / 60
        func total(_ t: (hour: Int, minute: Int)) -> Double { Double(t.hour * 60 + t.minute) }
        guard let index = all.lastIndex(where: { total($0.start) <= minutes }) else { return 0 }
        let period = all[index]
        let (start, end) = (total(period.start), total(period.end))
        if minutes >= end { return Double(index + 1) }
        return Double(index) + (minutes - start) / (end - start)
    }
}

public enum WeekdayName {
    /// 1 = 周一
    public static func short(_ weekday: Int) -> String { ["一", "二", "三", "四", "五", "六", "日"][(weekday - 1 + 7) % 7] }
    public static func full(_ weekday: Int) -> String { "周" + short(weekday) }
}

extension CourseOccurrence {
    /// "08:00–09:40"
    public var timeRangeText: String {
        guard let first = ClassPeriods.period(begin), let last = ClassPeriods.period(end) else { return "" }
        return "\(first.startText)–\(last.endText)"
    }

    /// "第1-2节"
    public var sectionText: String { begin == end ? "第\(begin)节" : "第\(begin)-\(end)节" }
}

/// 课程详情“导航”按钮的目标（RN `CourseDetailSheet`：体育学院的课按北 / 西 / 东直接搜场馆，其余按教室文案解析教学楼）
public enum CourseNavigation {
    public struct Target: Sendable, Hashable {
        /// 展示用的地点文案，也用来解析教学楼
        public var room: String
        /// 体育学院场馆的地图搜索词；有值时直接用它，不再解析教学楼
        public var mapKeyword: String?
    }

    public static func target(building: String, venue: String) -> Target? {
        let room = LocationFormatter.display(building: building, venue: venue)
        guard !room.isEmpty else { return nil }
        return Target(room: room, mapKeyword: (building + venue).contains("体育学院") ? sportsKeyword(room) : nil)
    }

    static func sportsKeyword(_ location: String) -> String? {
        if location.contains("北") { return "广西大学行健图书馆行健馆" }
        if location.contains("西") { return "广西大学西校园综合体育馆" }
        if location.contains("东") { return "广西大学东校园体育场" }
        return nil
    }
}
