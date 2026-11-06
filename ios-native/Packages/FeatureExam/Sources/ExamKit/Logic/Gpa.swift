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

    /// 绩点、加权平均、单门绩点统一保留两位小数、四舍五入（学校办法和教务系统口径，用户要求；RN 总绩点是三位）。
    /// 先加一个很小的偏移，避免 3.765 这类二进制误差被舍成 3.76。
    public static func format(_ value: Double) -> String {
        guard value.isFinite else { return "N/A" }
        let eps = value < 0 ? -1e-9 : 1e-9
        return String(format: "%.2f", ((value + eps) * 100).rounded(.toNearestOrAwayFromZero) / 100)
    }

    /// 单门绩点的展示文案（RN `calculatePoint`）：无成绩 "N/A"，不及格 "0"，否则 (score-50)/10 保留两位
    public static func pointText(for score: Double?) -> String {
        guard let score, score.isFinite else { return "N/A" }
        if score < 60 { return "0" }
        return format((score - 50) / 10)
    }
}
