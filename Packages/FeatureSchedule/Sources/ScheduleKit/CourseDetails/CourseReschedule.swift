import Foundation

package struct CourseReschedule: Decodable, Sendable {
    package struct Slot: Hashable, Sendable {
        let week: Int
        let weekday: Int
        let sections: ClosedRange<Int>

        package init(week: Int, weekday: Int, sections: ClosedRange<Int>) {
            self.week = week
            self.weekday = weekday
            self.sections = sections
        }
    }

    package struct Arrangement: Decodable, Sendable {
        package let weeks: String?
        package let weekday: String?
        package let sections: String?
        package let teacher: String?
        package let venueName: String?

        package var slots: [Slot] {
            guard let weeks, let weekday, let sections else { return [] }
            let day = weekday.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let weekday = (1...7).first(where: {
                day == WeekdayName.short($0) || day == WeekdayName.full($0) || day == "星期\(WeekdayName.short($0))"
            }) else { return [] }
            let periods = WeekParser.parse(Self.normalize(sections), within: 1...ClassPeriods.count)
            guard let first = periods.first, let last = periods.last, periods.count == last - first + 1 else { return [] }
            return WeekParser.parse(Self.normalize(weeks), within: 1...TermCalendar.maximumWeeks).map {
                Slot(week: $0, weekday: weekday, sections: first...last)
            }
        }

        private static func normalize(_ text: String) -> String {
            text.replacingOccurrences(of: "[，、]", with: ",", options: .regularExpression)
                .replacingOccurrences(of: "[－–至]", with: "-", options: .regularExpression)
                .replacingOccurrences(of: "（", with: "(")
                .replacingOccurrences(of: "）", with: ")")
                .replacingOccurrences(of: "[第周节]", with: "", options: .regularExpression)
        }
    }

    package let type: String?
    package let reason: String?
    package let reasonCategory: String?
    package let before: Arrangement
    package let after: Arrangement
}
