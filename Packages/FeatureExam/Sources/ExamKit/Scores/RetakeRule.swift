import Foundation

public struct RetakeResolution: Equatable, Sendable {
    public var counted: [Score]
    public var overridden: [Score]
    public var retakeIDs: Set<String>
}

public enum RetakeRule {
    public static func resolve(_ scores: [Score]) -> RetakeResolution {
        struct Key: Hashable { var name: String; var credit: Double? }
        var groups: [Key: [(index: Int, score: Score)]] = [:]
        for (index, score) in scores.enumerated() {
            groups[Key(name: score.courseName, credit: score.credit), default: []].append((index, score))
        }
        var kept = Set<String>()
        var retake = Set<String>()
        for group in groups.values {
            let scored = group.filter { $0.score.score != nil }
            guard let best = scored.max(by: { a, b in
                let (sa, sb) = (a.score.score ?? 0, b.score.score ?? 0)
                if sa != sb { return sa < sb }
                let (oa, ob) = (order(a.score), order(b.score))
                return oa == ob ? a.index < b.index : oa < ob
            }) else {
                group.forEach { kept.insert($0.score.id) }
                continue
            }
            kept.insert(best.score.id)
            if scored.count > 1 { retake.insert(best.score.id) }
        }
        return RetakeResolution(
            counted: scores.filter { kept.contains($0.id) },
            overridden: scores.filter { !kept.contains($0.id) },
            retakeIDs: retake
        )
    }

    private struct Order: Comparable {
        var year: Int, term: Int, uploadAt: String
        static func < (a: Order, b: Order) -> Bool { (a.year, a.term, a.uploadAt) < (b.year, b.term, b.uploadAt) }
    }

    private static func order(_ s: Score) -> Order {
        Order(year: s.year, term: s.term == 0 ? 3 : s.term, uploadAt: s.uploadAt)
    }
}
