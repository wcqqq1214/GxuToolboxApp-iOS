import Foundation

public struct GpaResult: Equatable, Sendable {
    public var gpa: Double
    public var wam: Double
    public static let zero = GpaResult(gpa: 0, wam: 0)
}

public enum GpaCalculator {
    public static func calculate(_ scores: [Score]) -> GpaResult {
        var denominator = 0.0, gpaNumerator = 0.0, wamNumerator = 0.0
        for item in scores {
            guard let score = item.score, let credit = item.credit, score.isFinite, credit.isFinite else { continue }
            if score >= 60 { gpaNumerator += (score / 10 - 5) * credit }
            denominator += credit
            wamNumerator += credit * score
        }
        guard denominator > 0 else { return .zero }
        return GpaResult(gpa: gpaNumerator / denominator, wam: wamNumerator / denominator)
    }

    public static func format(_ value: Double) -> String {
        guard value.isFinite else { return "N/A" }
        let eps = value < 0 ? -1e-9 : 1e-9
        return String(format: "%.2f", ((value + eps) * 100).rounded(.toNearestOrAwayFromZero) / 100)
    }

    public static func pointText(for score: Double?) -> String {
        guard let score, score.isFinite else { return "N/A" }
        if score < 60 { return "0" }
        return format((score - 50) / 10)
    }
}
