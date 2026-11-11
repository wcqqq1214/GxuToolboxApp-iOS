import Foundation

public enum WeekParser {
    public static func parse(_ text: String) -> [Int] {
        parse(text, within: nil)
    }

    static func parse(_ text: String, within bounds: ClosedRange<Int>?) -> [Int] {
        var result = Set<Int>()
        for segment in text.split(separator: ",") {
            let raw = String(segment)
            let clean = raw
                .replacingOccurrences(of: "周", with: "")
                .replacingOccurrences(of: #"\(.*?\)"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !clean.isEmpty else { continue }
            if clean.contains("-") {
                let endpoints = clean.split(separator: "-", omittingEmptySubsequences: false).map { Int($0.trimmingCharacters(in: .whitespaces)) }
                guard endpoints.count == 2, let start = endpoints[0], let end = endpoints[1], start <= end,
                      bounds?.contains(start) != false, bounds?.contains(end) != false else { continue }
                let range = Array(start...end)
                if raw.contains("(单)") {
                    result.formUnion(range.filter { $0 % 2 == 1 })
                } else if raw.contains("(双)") {
                    result.formUnion(range.filter { $0 % 2 == 0 })
                } else {
                    result.formUnion(range)
                }
            } else if let week = Int(clean), bounds?.contains(week) != false {
                result.insert(week)
            }
        }
        return result.sorted()
    }
}
