import Foundation

struct ModuleStats: Equatable {
    var score: Double = 0
    var has = false

    mutating func add(_ credit: Double) {
        has = true
        score += credit
    }
}

struct ElectiveStats: Equatable {
    var totalScore: Double = 0
    var offlineScore: Double = 0
    var lead = ModuleStats()
    var entrepreneurship = ModuleStats()
    var art = ModuleStats()
    var asean = ModuleStats()
    var ocean = ModuleStats()
    var ethnic = ModuleStats()
    var specialModulesCount: Int { (asean.has ? 1 : 0) + (ethnic.has ? 1 : 0) + (ocean.has ? 1 : 0) }
    var remainingRequired: [String] = []
    var passed: [String: Bool] = [:]

    var isQualified: Bool { passed.values.allSatisfy { $0 } }
}

struct ElectiveRow: Equatable, Identifiable {
    var id: String
    var label: String
    var value: String
    var passed: Bool
}

struct ElectiveStrategy {
    enum Kind { case y2021, credit(art: Double), modern }

    var grade: Int
    var kind: Kind
    var totalRequired: Double
    var offlineRequired: Double
    var requiredCourses: [String]

    var name: String { "\(grade) 级校选课毕业要求" }

    func calculate(_ courses: [SelectedCourse]) -> ElectiveStats {
        var s = ElectiveStats()
        var remaining = requiredCourses
        for course in courses {
            let credit = course.credit.isFinite ? course.credit : 0
            s.totalScore += credit
            if !course.isOnline { s.offlineScore += credit }

            if course.system.contains("领军") || course.system.contains("伦理") { s.lead.add(credit) }
            if course.system.contains("创业") { s.entrepreneurship.add(credit) }
            if course.system.contains("艺术") { s.art.add(credit) }
            if course.system.contains("东盟") { s.asean.add(credit) }
            if course.system.contains("民族") { s.ethnic.add(credit) }
            if course.system.contains("海洋") { s.ocean.add(credit) }

            remaining.removeAll { $0 == course.courseName }
        }
        s.remainingRequired = remaining

        var passed: [String: Bool] = [
            "totalScore": s.totalScore >= totalRequired,
            "requiredCourses": remaining.isEmpty,
        ]
        switch kind {
        case .y2021:
            passed["offlineScore"] = s.offlineScore >= offlineRequired && s.offlineScore / s.totalScore <= 0.5
            passed["artScore"] = s.art.has
            passed["specialModules"] = s.specialModulesCount >= 2
            passed["leadModule"] = s.lead.has
            passed["entModule"] = s.entrepreneurship.has
        case .credit(let art):
            passed["offlineScore"] = s.offlineScore >= offlineRequired
            passed["artScore"] = s.art.score >= art
            passed["specialModules"] = s.specialModulesCount >= 2
            passed["leadModule"] = s.lead.has
            passed["entModule"] = s.entrepreneurship.has
        case .modern:
            passed["offlineScore"] = s.offlineScore >= offlineRequired
            passed["artScore"] = s.art.score >= 2
            passed["tech"] = s.lead.score >= 1
            passed["ethnic"] = s.ethnic.score >= 1
            passed["ocean"] = s.ocean.score >= 1
            passed["asean"] = s.asean.score >= 1
        }
        s.passed = passed
        return s
    }

    func rows(_ s: ElectiveStats) -> [ElectiveRow] {
        func credit(_ id: String, _ label: String, _ value: Double, _ required: Double) -> ElectiveRow {
            ElectiveRow(id: id, label: "\(label)（要求 \(Self.number(required))）", value: "\(Self.number(value)) / \(Self.number(required))", passed: value >= required)
        }
        func done(_ id: String, _ label: String, _ has: Bool) -> ElectiveRow {
            ElectiveRow(id: id, label: label, value: has ? "已完成" : "未完成", passed: has)
        }
        let total = credit("totalScore", "总学分", s.totalScore, totalRequired)
        let offline = credit("offlineScore", "线下学分", s.offlineScore, offlineRequired)
        let special = ElectiveRow(id: "special", label: "东盟、海洋、民族（三选二）", value: "\(s.specialModulesCount) / 2", passed: s.specialModulesCount >= 2)
        switch kind {
        case .y2021:
            return [total, offline, done("lead", "领军模块", s.lead.has), done("ent", "创业模块", s.entrepreneurship.has), special]
        case .credit(let art):
            return [total, offline, credit("art", "公共艺术学分", s.art.score, art), done("lead", "领军模块", s.lead.has), done("ent", "创业模块", s.entrepreneurship.has), special]
        case .modern:
            return [
                total, offline,
                credit("ent", "创业学分", s.entrepreneurship.score, 2),
                credit("art", "艺术与审美", s.art.score, 2),
                credit("tech", "科技与伦理", s.lead.score, 1),
                credit("ethnic", "少数民族与中华文明", s.ethnic.score, 1),
                credit("ocean", "亚热带与海洋生态", s.ocean.score, 1),
                credit("asean", "东盟历史与世界文化", s.asean.score, 1),
            ]
        }
    }

    static func number(_ v: Double) -> String {
        guard v.isFinite else { return "0" }
        return v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : String(v)
    }
}

enum ElectiveStrategies {
    private static let threeRequired = ["创业基础", "中文写作实训", "逻辑与批判性思维训练"]
    private static let fourRequired = threeRequired + ["中华民族共同体概论"]

    static let all: [Int: ElectiveStrategy] = [
        2021: ElectiveStrategy(grade: 2021, kind: .y2021, totalRequired: 8, offlineRequired: 4, requiredCourses: threeRequired),
        2022: ElectiveStrategy(grade: 2022, kind: .credit(art: 2), totalRequired: 10, offlineRequired: 5, requiredCourses: threeRequired),
        2023: ElectiveStrategy(grade: 2023, kind: .credit(art: 2), totalRequired: 10, offlineRequired: 5, requiredCourses: fourRequired),
        2024: ElectiveStrategy(grade: 2024, kind: .credit(art: 2), totalRequired: 10, offlineRequired: 5, requiredCourses: fourRequired),
        2025: ElectiveStrategy(grade: 2025, kind: .modern, totalRequired: 8, offlineRequired: 4, requiredCourses: ["创新创业基础"]),
        2026: ElectiveStrategy(grade: 2026, kind: .modern, totalRequired: 8, offlineRequired: 4, requiredCourses: ["创新创业基础"]),
    ]

    static func strategy(forGrade grade: Int) -> ElectiveStrategy {
        all[grade] ?? all[2025]!
    }
}
