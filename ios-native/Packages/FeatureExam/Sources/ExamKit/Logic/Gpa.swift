import Foundation

public struct GpaResult: Equatable, Sendable {
    /// 平均学分绩点
    public var gpa: Double
    /// 加权平均成绩
    public var wam: Double
    public static let zero = GpaResult(gpa: 0, wam: 0)
}

/// 移植自 RN `useGpa`，依据《广西大学普通本科学生课程修读、考核及成绩管理办法（2019年修订）》。
public enum GpaCalculator {
    /// 单门绩点 = 成绩 / 10 - 5，仅 ≥ 60 分计入分子；不及格课程学分仍计入分母。
    /// 与 RN 的差异：成绩或学分无法解析的课程直接跳过（RN 会算出 NaN）；分母为 0 时返回 0。
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

    /// 单门绩点的展示文案（RN `calculatePoint`）：无成绩 "N/A"，不及格 "0"，否则 (score-50)/10 保留两位
    public static func pointText(for score: Double?) -> String {
        guard let score, score.isFinite else { return "N/A" }
        if score < 60 { return "0" }
        return String(format: "%.2f", (score - 50) / 10)
    }
}
