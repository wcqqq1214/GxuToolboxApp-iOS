import Foundation

public enum WeekFormatter {
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
    public static func display(building: String, venue: String) -> String {
        let room = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        let hall = building.trimmingCharacters(in: .whitespacesAndNewlines)
        if room.isEmpty { return hall }
        if (hall + room).contains("体育学院") { return fullText(building: hall, venue: room) }
        return room
    }

    public static func fullText(building: String, venue: String) -> String {
        let full = building + venue
        guard full.contains("体育学院"), let index = full.firstIndex(where: { "北西东".contains($0) }) else { return full }
        return String(full[index...])
    }

    public static func blockText(venue: String, singleLine: Bool) -> String {
        singleLine ? venue : venue.replacingOccurrences(of: "-", with: "\n")
    }
}

public extension ClassPeriods {
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
    public static func short(_ weekday: Int) -> String { ["一", "二", "三", "四", "五", "六", "日"][(weekday - 1 + 7) % 7] }
    public static func full(_ weekday: Int) -> String { "周" + short(weekday) }
}

extension CourseOccurrence {
    public var timeRangeText: String {
        guard let first = ClassPeriods.period(begin), let last = ClassPeriods.period(end) else { return "" }
        return "\(first.startText)–\(last.endText)"
    }

    public var sectionText: String { begin == end ? "第\(begin)节" : "第\(begin)-\(end)节" }
}

public enum CourseNavigation {
    public struct Target: Sendable, Hashable {
        public var text: String
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
