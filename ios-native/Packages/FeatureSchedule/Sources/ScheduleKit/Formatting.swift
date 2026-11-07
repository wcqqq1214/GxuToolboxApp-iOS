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
    /// 界面上显示的地点（课程详情、课程块、首页、附件、分享图、小组件都用它）：只显示教室 `venueName`（如 “西2-202”“6A-307”），
    /// 不再拼楼名；教室为空才显示楼名。体育学院的课保留原规则：只保留“北 / 西 / 东”及之后的部分（“体育学院西体育馆” → “西体育馆”）。
    public static func display(building: String, venue: String) -> String {
        let room = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        let hall = building.trimmingCharacters(in: .whitespacesAndNewlines)
        if room.isEmpty { return hall }
        if (hall + room).contains("体育学院") { return fullText(building: hall, venue: room) }
        return room
    }

    /// 完整的楼名 + 教室（“西三教西3-406”），体育学院的课只保留“北 / 西 / 东”及之后的部分。显示用（`display`）只在体育学院时走这里；
    /// 导航不用它，用 `CourseNavigation`（按 RN 的 `楼名 | 教室` 文案解析）。
    public static func fullText(building: String, venue: String) -> String {
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

/// 课程详情“导航到这里”的目标（RN `CourseDetailSheet`）：
/// - 解析用的文案 `text`：楼名含“体育学院”时只用教室，否则 `楼名 | 教室`（RN `displayLocation`）；
/// - 体育学院的课（楼名 + 教室里含“体育学院”）按文案里的 北 / 西 / 东 直接搜场馆，不再解析教学楼（RN `resolveSportsCollegeMapKeyword`）。
/// 界面上显示的地点仍然只显示教室（`LocationFormatter.display`）；这里的文案只用来解析楼名，不显示。
public enum CourseNavigation {
    public struct Target: Sendable, Hashable {
        /// 交给楼名解析的文案（RN `displayLocation`）
        public var text: String
        /// 体育学院场馆的地图搜索词；有值时直接用它
        public var mapKeyword: String?

        public init(text: String, mapKeyword: String?) {
            self.text = text
            self.mapKeyword = mapKeyword
        }
    }

    public static func target(building: String, venue: String) -> Target? {
        guard !(building + venue).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let text = building.contains("体育学院") ? venue : "\(building) | \(venue)"
        let isSportsCollege = (building + venue).contains("体育学院")
        return Target(text: text, mapKeyword: isSportsCollege ? sportsKeyword(text) : nil)
    }

    static func sportsKeyword(_ location: String) -> String? {
        if location.contains("北") { return "广西大学行健图书馆行健馆" }
        if location.contains("西") { return "广西大学西校园综合体育馆" }
        if location.contains("东") { return "广西大学东校园体育场" }
        return nil
    }
}
