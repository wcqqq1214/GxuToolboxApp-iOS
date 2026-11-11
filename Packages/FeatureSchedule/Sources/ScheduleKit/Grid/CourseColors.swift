import Foundation

public enum CoursePalette: String, Codable, Sendable, CaseIterable {
    case macaron, morandi, vivid

    public var displayName: String {
        switch self {
        case .macaron: "马卡龙"
        case .morandi: "莫兰迪"
        case .vivid: "鲜艳"
        }
    }

    public var colors: [UInt32] {
        switch self {
        case .macaron:
            [0xFFB7B2, 0xFFDAC1, 0xE2F0CB, 0xB5EAD7, 0xC7CEEA, 0xF8BBD0, 0xE1BEE7, 0xD1C4E9,
             0xC5CAE9, 0xB3E5FC, 0xB2DFDB, 0xDCEDC8, 0xFFF9C4, 0xFFECB3, 0xFFE0B2]
        case .morandi:
            [0xA8B6B2, 0x90A4AE, 0x78909C, 0xB0BEC5, 0xCFD8DC, 0xBCAAA4, 0xA1887F, 0x8D6E63,
             0xD7CCC8, 0xEFEBE9, 0xFFE082, 0xFFCA28, 0xFFB300, 0xFFD54F, 0xFFECB3]
        case .vivid:
            [0xFF5252, 0xFF4081, 0xE040FB, 0x7C4DFF, 0x536DFE, 0x448AFF, 0x40C4FF, 0x18FFFF,
             0x64FFDA, 0x69F0AE, 0xB2FF59, 0xEEFF41, 0xFFFF00, 0xFFD740, 0xFFAB40]
        }
    }
}

public enum CourseColorAssigner {
    public static func assign(
        courses: [TheoryCourse], palette: CoursePalette = .macaron, custom: [String: UInt32] = [:]
    ) -> [String: UInt32] {
        let names = Array(Set(courses.map(\.courseName))).sorted()
        let slots = Dictionary(grouping: courses.filter(\.isValid), by: \.courseName)

        var adjacency: [String: Set<String>] = Dictionary(uniqueKeysWithValues: names.map { ($0, []) })
        for (i, a) in names.enumerated() {
            for b in names[(i + 1)...] where isAdjacent(slots[a] ?? [], slots[b] ?? []) {
                adjacency[a]?.insert(b)
                adjacency[b]?.insert(a)
            }
        }

        let ordered = names.sorted { (adjacency[$0]?.count ?? 0, $1) > (adjacency[$1]?.count ?? 0, $0) }
        let colors = palette.colors
        var assigned: [String: UInt32] = [:]

        for name in ordered {
            if let color = custom[name] {
                assigned[name] = color
                continue
            }
            let neighbors = (adjacency[name] ?? []).compactMap { assigned[$0] }
            let used = Set(assigned.values)
            let unusedNonNeighbor = colors.filter { !used.contains($0) && !neighbors.contains($0) }
            let nonNeighbor = colors.filter { !neighbors.contains($0) }
            let pool = !unusedNonNeighbor.isEmpty ? unusedNonNeighbor : (!nonNeighbor.isEmpty ? nonNeighbor : colors)

            if neighbors.isEmpty {
                assigned[name] = pool[Int(abs(Int64(hash(name))) % Int64(pool.count))]
            } else {
                func score(_ c: UInt32) -> Double { neighbors.map { distance(c, $0) }.min() ?? 0 }
                assigned[name] = pool.reduce(pool[0]) { score($1) > score($0) ? $1 : $0 }
            }
        }
        return assigned
    }

    private static func isAdjacent(_ a: [TheoryCourse], _ b: [TheoryCourse]) -> Bool {
        a.contains { x in b.contains { y in x.weekday == y.weekday && (abs(x.begin - y.end) <= 1 || abs(y.begin - x.end) <= 1) } }
    }

    static func hash(_ text: String) -> Int32 {
        var h: Int32 = 0
        for unit in text.utf16 { h = Int32(truncatingIfNeeded: Int(unit)) &+ ((h &<< 5) &- h) }
        return h
    }

    private static func distance(_ a: UInt32, _ b: UInt32) -> Double {
        func rgb(_ c: UInt32) -> (Double, Double, Double) { (Double((c >> 16) & 0xFF), Double((c >> 8) & 0xFF), Double(c & 0xFF)) }
        let (r1, g1, b1) = rgb(a), (r2, g2, b2) = rgb(b)
        return ((r1 - r2) * (r1 - r2) + (g1 - g2) * (g1 - g2) + (b1 - b2) * (b1 - b2)).squareRoot()
    }
}
