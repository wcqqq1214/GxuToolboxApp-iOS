import Foundation

public enum WeekParser {
    /// 把教务的周次文案展开成升序去重的周次数组。
    /// `"1-4周,6-9周(双)"` → `[1,2,3,4,6,8]`；`"5周"` → `[5]`；无法识别的段落被跳过。
    public static func parse(_ text: String) -> [Int] {
        var result = Set<Int>()
        for segment in text.split(separator: ",") {
            let raw = String(segment)
            let clean = raw
                .replacingOccurrences(of: "周", with: "")
                .replacingOccurrences(of: #"\(.*?\)"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard !clean.isEmpty else { continue }
            if clean.contains("-") {
                let bounds = clean.split(separator: "-", omittingEmptySubsequences: false).map { Int($0.trimmingCharacters(in: .whitespaces)) }
                guard bounds.count == 2, let start = bounds[0], let end = bounds[1], start <= end else { continue }
                let range = Array(start...end)
                if raw.contains("(单)") {
                    result.formUnion(range.filter { $0 % 2 == 1 })
                } else if raw.contains("(双)") {
                    result.formUnion(range.filter { $0 % 2 == 0 })
                } else {
                    result.formUnion(range)
                }
            } else if let week = Int(clean) {
                result.insert(week)
            }
        }
        return result.sorted()
    }
}
