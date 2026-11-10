import Foundation

/// 绩点页对多次修读同一门课的处理，依据《广西大学普通本科学生课程修读、考核及成绩管理办法（2019年修订）》（西大教〔2019〕26号）
/// 第三十八条（二）：学生多次修读同一门课程获得的多个有效成绩，可按最高成绩列入毕业审核、计入毕业成绩档案，
/// 相应的课程、学分、成绩只能计算一次。
///
/// 官方条文针对毕业成绩档案；工具箱把它用于所选的全部范围（全部学期、全学年、单个学期），官方结果以教务处为准。
///
/// - 同一门课：`课程名 + 学分` 相同（`/jw/score` 没有课程编号；`id` 是教学班，每次修读都不同）。
/// - **同一门课在范围内只计一次，取最高成绩**；分数相同取最新的一条（`year`，再 `term`——秋 1、春 2、小学期 0 排在同学年春季之后，
///   再 `upload_at`——可能为空，空的排最前，最后是原来的顺序）。
/// - 及格和不及格一视同仁：同名都及格的也只算一次。
/// - 还没有成绩（`score == nil`）的记录不参与比较，只在这门课一条成绩都没有时保留（`GpaCalculator` 会跳过它）。
/// - 只在传进来的记录里合并：调用方传"所选范围内的记录"，单个学期就不会被其他学期的成绩改写。
/// - 公式和分母不变：不及格课程的学分仍计入分母，只是同一门课只出现一次。
public struct RetakeResolution: Equatable, Sendable {
    /// 实际计入的成绩，保持传入的顺序
    public var counted: [Score]
    /// 同一门课里没被采用的记录
    public var overridden: [Score]
    /// 在 `counted` 里、这门课范围内有多次修读的那条（界面标"重修"）的 id
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
                group.forEach { kept.insert($0.score.id) }   // 一条成绩都没有：都留着（计算时会被跳过）
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
