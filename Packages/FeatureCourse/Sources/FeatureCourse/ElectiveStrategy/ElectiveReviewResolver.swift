import ExamKit
import Foundation

/// 后端把校选课标成"待核对"（`status = review`）时，用本地成绩记录核对（纯函数，不联网）。
///
/// 依据：学籍规定第十九条"考核总评达到合格标准的即取得学分"，所以成绩记录里有唯一一条对得上的及格成绩，
/// 就能确认这门课的分数、及格状态和学分。对得上 = 课程名一致 + 学分一致（用 attempt.credit）+ 学年一致 +
/// 学期一致；后端把小学期记成 term 3，成绩接口记成 term 0，这两个视为同一学期（后端待办见 rn-v2.2-gap.md）。
/// 对得上的记录不唯一或没有时保留"待核对"，并写明具体原因，不显示"数据存在歧义"。
public struct ElectiveReviewResult: Sendable, Equatable {
    public var progress: ElectiveProgress
    /// courseId → 已按成绩记录核对（课程行小字）
    public var confirmed: [String: String]
    /// courseId → 仍待核对的具体原因
    public var unresolved: [String: String]
}

public enum ElectiveReviewResolver {
    public static let confirmedNote = "已按成绩记录核对"

    /// 后端 term 3（小学期）↔ 成绩接口 term 0
    static func termMatches(attempt: Int, score: Int) -> Bool {
        attempt == score || (attempt == 3 && score == 0) || (attempt == 0 && score == 3)
    }

    private static let moduleKeys: [String: ElectiveProgress.Module] = [
        "lead": .lead, "entrepreneurship": .entrepreneurship, "art": .art, "asean": .asean, "ethnic": .ethnic, "ocean": .ocean,
    ]
    /// 后端的"特色模块数"要求包含这些模块；新覆盖到其中之一时我们没法单独重算
    private static let specialModules: Set<ElectiveProgress.Module> = [.asean, .ethnic, .ocean]

    public static func resolve(_ progress: ElectiveProgress, scores: [Score]?) -> ElectiveReviewResult {
        var result = progress
        var confirmed: [String: String] = [:]
        var unresolved: [String: String] = [:]
        var resolvedIDs = Set<String>()

        for (index, course) in progress.courses.enumerated() where course.status == .review {
            switch match(course, scores: scores) {
            case .failure(let reason):
                unresolved[course.id] = reason.text
                result.courses[index].excludedReason = reason.text
            case .success(let found):
                var c = course
                let value = found.score ?? 0
                c.score = value
                c.credit = found.credit
                c.status = value >= 60 ? .passed : .failed
                c.counted = value >= 60
                c.countedCredits = value >= 60 ? (found.credit ?? 0) : 0
                c.excludedReason = value >= 60 ? nil : "成绩未达到合格标准，不计学分"
                if c.online == nil { c.online = course.attempts.first { $0.status == .review }?.online }
                result.courses[index] = c
                confirmed[course.id] = confirmedNote
                resolvedIDs.insert(course.courseId)
            }
        }
        guard !resolvedIDs.isEmpty else { return ElectiveReviewResult(progress: result, confirmed: confirmed, unresolved: unresolved) }

        // 已核对课程对应的 issue 去掉；其它 issue 原样保留
        let handled = Set(progress.courses.filter { confirmed[$0.id] != nil }.map(\.courseId))
        result.issues = progress.issues.filter { !handled.contains($0.courseId) }
        recompute(&result, original: progress, resolved: handled)
        return ElectiveReviewResult(progress: result, confirmed: confirmed, unresolved: unresolved)
    }

    private static func match(_ course: ElectiveProgress.Course, scores: [Score]?) -> Result<Score, ReasonError> {
        guard let scores, !scores.isEmpty else { return .failure(ReasonError(text: "成绩记录暂时无法读取，无法核对")) }
        let reviewAttempts = course.attempts.filter { $0.status == .review }
        guard reviewAttempts.count == 1, let attempt = reviewAttempts.first else {
            return .failure(ReasonError(text: reviewAttempts.isEmpty ? "选课记录里没有这门课的修读信息，无法核对" : "这门课有多条待核对的修读记录，无法确定对应哪条成绩"))
        }
        guard let credit = attempt.credit ?? course.credit else { return .failure(ReasonError(text: "选课记录缺少学分，无法核对")) }
        let sameName = scores.filter { $0.courseName == course.courseName }
        guard !sameName.isEmpty else { return .failure(ReasonError(text: "成绩记录里没有这门课")) }
        let sameCredit = sameName.filter { $0.credit == credit }
        guard !sameCredit.isEmpty else { return .failure(ReasonError(text: "成绩记录里这门课的学分与选课记录不一致")) }
        let sameTerm = sameCredit.filter { $0.year == attempt.year && termMatches(attempt: attempt.term, score: $0.term) }
        guard !sameTerm.isEmpty else { return .failure(ReasonError(text: "成绩记录里没有\(attempt.year)学年对应学期的这门课")) }
        let withScore = sameTerm.filter { $0.score != nil }
        guard !withScore.isEmpty else { return .failure(ReasonError(text: "成绩记录里这门课还没有成绩")) }
        guard Set(withScore.map(\.id)).count == 1, let only = withScore.first else {
            return .failure(ReasonError(text: "成绩记录里有多条同名同学分的记录，无法确定对应哪一条"))
        }
        return .success(only)
    }

    /// 重算能由课程列表推出来的统计和要求；推不出来的要求保持后端的值，并在可能受影响时保持"待核对"
    private static func recompute(_ p: inout ElectiveProgress, original: ElectiveProgress, resolved: Set<String>) {
        let counted = p.courses.filter(\.counted)
        func credits(_ c: ElectiveProgress.Course) -> Double { c.countedCredits }
        p.stats.totalCredits = counted.reduce(0) { $0 + credits($1) }
        p.stats.offlineCredits = counted.filter { $0.online == false }.reduce(0) { $0 + credits($1) }
        func moduleStats(_ m: ElectiveProgress.Module) -> ElectiveProgress.ModuleStats {
            let list = counted.filter { $0.modules.contains(m) }
            return .init(credits: list.reduce(0) { $0 + credits($1) }, courseCount: list.count)
        }
        p.stats.modules = .init(lead: moduleStats(.lead), entrepreneurship: moduleStats(.entrepreneurship), art: moduleStats(.art),
                                asean: moduleStats(.asean), ethnic: moduleStats(.ethnic), ocean: moduleStats(.ocean))

        var allRecomputed = true
        for i in p.requirements.indices {
            let item = p.requirements[i]
            var actual: Double?
            if item.key == "totalCredits" { actual = p.stats.totalCredits }
            else if item.key == "offlineCredits" { actual = p.stats.offlineCredits }
            else if let module = moduleKeys[item.key] {
                let s = moduleStats(module)
                actual = item.unit == .courses ? Double(s.courseCount) : s.credits
            }
            if let actual {
                p.requirements[i].actual = actual
                p.requirements[i].passed = item.operator == .gte ? actual >= item.required : actual <= item.required
            } else {
                // 特色模块数、指定课程等：后端的规则，不重算；用后端原来的 actual 判断
                allRecomputed = false
                p.requirements[i].passed = item.operator == .gte ? item.actual >= item.required : item.actual <= item.required
            }
        }
        // 新覆盖到特色模块、或补上了尚未完成的指定课程：后端的值已经过期，不能自己判断，保持待核对
        let touched = p.courses.filter { resolved.contains($0.courseId) }
        let newSpecial = touched.contains { c in
            c.modules.contains { specialModules.contains($0) && original.stats.credits(of: $0) == 0 }
        }
        let touchesRequired = touched.contains { original.remainingRequired.contains($0.courseName) }
        p.remainingRequired = original.remainingRequired
        let needsBackend = (!allRecomputed && (newSpecial || touchesRequired))
        let stillReview = p.courses.contains { $0.status == .review }
        p.complete = p.issues.isEmpty && !stillReview && !needsBackend
        p.isQualified = p.complete ? p.requirements.allSatisfy { $0.passed == true } : nil
    }
}

private struct ReasonError: Error, Equatable { let text: String }

private extension ElectiveProgress.Stats {
    func credits(of m: ElectiveProgress.Module) -> Double {
        switch m {
        case .lead: modules.lead.credits
        case .entrepreneurship: modules.entrepreneurship.credits
        case .art: modules.art.credits
        case .asean: modules.asean.credits
        case .ethnic: modules.ethnic.credits
        case .ocean: modules.ocean.credits
        }
    }
}
