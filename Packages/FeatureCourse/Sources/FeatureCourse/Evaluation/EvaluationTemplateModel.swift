import Foundation
import GxuFoundation
import GxuStorage

/// 评教模板：16 道题（移植自 RN `EvaluationTemplate.tsx`，分 5 类：4 + 3 + 3 + 3 + 3）× 5 个等级 + 评语。
/// RN 把"当前模板"放在 AsyncStorage、命名模板放在 SQLite（两套并存）；iOS 只用 GRDB 一张表。
public enum EvaluationQuestions {
    public static let levels = ["非常满意", "满意", "一般", "不满意", "非常不满意"]
    public static let categorySizes = [4, 3, 3, 3, 3]
    public static let items: [String] = [
        "依法执教。任课教师遵守宪法和法律法规，贯彻党和国家教育方针，依法履责，在教育教学活动中无违背党的路线方针政策的不当言行。",
        "廉洁从教。任课教师严于律己，作风严谨正派；清廉从教，以身作则，无索要或收受学生及家长的财物馈赠行为。",
        "教书育人。任课教师遵循教育规律，维护课堂秩序；恪守学术规范，注重学思结合，因材施教，严慈相济，促进学生全面发展。",
        "立德树人。任课教师具优良教风，以高尚师德、人格魅力和学识风范教育感染学生；遵守社会公德，言行雅正；关心关爱、公正对待学生，做学生的良师益友。",
        "任课教师准时上下课，无调课、停课、缺课等现象。",
        "任课教师讲课有激情，精神饱满，有感染力，能吸引我的注意力。",
        "任课教师作业批改认真，课后我有疑问时，能得到老师的及时反馈与耐心指导。",
        "任课教师对课程内容娴熟，不照本宣科，与时俱进，难易得当，我能轻松理解。",
        "作业和考试既覆盖了课程的主要知识点，也能给我一定的发挥空间。",
        "任课教师制定并开展了“课程思政”教学设计，注重把思政教育融入课堂教学各环节。",
        "任课教师公布教学计划，明确告知教学目标、学习任务、考核方法、成绩构成比例并严格执行。",
        "任课教师能调动我的情绪，课堂气氛活跃、注重互动能激发我的学习兴趣。",
        "任课教师及时了解班级同学的学习进程、存在问题和学习效果，并作出相应调整与改进。",
        "该课程各教学环节的设置合理，使我有效学习、掌握课程相关知识、技能。",
        "本课程选用的教材、任课教师推荐的课程资源对我的学习有帮助。",
        "任课教师对我的思想言行和成长产生了积极影响，引导我树立正确的历史观、民族观、国家观、文化观和人生观。"
    ]
    /// 默认等级下标（RN：全部"满意"）
    public static let defaultLevel = 1
    public static var defaultAnswers: [Int] { Array(repeating: defaultLevel, count: items.count) }
}

public struct EvaluationTemplate: Hashable, Sendable, Identifiable {
    /// 数据库主键；新建时为 nil
    public var id: Int64?
    public var name: String
    /// 每题选的等级下标（0 = 非常满意 … 4 = 非常不满意），长度 = 题数
    public var answers: [Int]
    public var comment: String
    public var updatedAt: Date

    public init(id: Int64? = nil, name: String, answers: [Int] = EvaluationQuestions.defaultAnswers, comment: String = "", updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.answers = EvaluationTemplate.normalized(answers)
        self.comment = comment
        self.updatedAt = updatedAt
    }

    /// 补齐 / 截断到题数；越界的等级回退到默认（存储里的数据可能来自旧版本）
    static func normalized(_ answers: [Int]) -> [Int] {
        let count = EvaluationQuestions.items.count
        let levels = EvaluationQuestions.levels.count
        return (0..<count).map { i in
            guard i < answers.count, (0..<levels).contains(answers[i]) else { return EvaluationQuestions.defaultLevel }
            return answers[i]
        }
    }
}

struct EvaluationTemplateRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "evaluation_template"
    var id: Int64?
    var studentId: String
    var name: String
    var answersJSON: String
    var comment: String
    var updatedAt: Date

    mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

/// 评教模板的本地存储，按 studentId 隔离，同一账号下名称唯一
public struct EvaluationTemplateRepository: Sendable {
    let database: AppDatabase

    public init(database: AppDatabase) { self.database = database }

    static func registerMigrations(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("course.v3.createEvaluationTemplate") { db in
            try db.create(table: "evaluation_template") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("studentId", .text).notNull()
                t.column("name", .text).notNull()
                t.column("answersJSON", .text).notNull()
                t.column("comment", .text).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.uniqueKey(["studentId", "name"])
            }
        }
    }

    /// 最近修改的在前
    public func list(studentId: String) async throws -> [EvaluationTemplate] {
        try await database.writer.read { db in
            try EvaluationTemplateRecord.filter(Column("studentId") == studentId).order(Column("updatedAt").desc, Column("id").desc)
                .fetchAll(db).map(Self.template)
        }
    }

    /// 新建或更新（`id` 为 nil 新建，否则按 id 更新）。名称不能为空，也不能和同账号下别的模板重名
    @discardableResult
    public func save(_ template: EvaluationTemplate, studentId: String, now: Date = .now) async throws -> EvaluationTemplate {
        let name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw GxuError.invalidData("请输入模板名称") }
        let json = String(decoding: try JSONEncoder().encode(EvaluationTemplate.normalized(template.answers)), as: UTF8.self)
        return try await database.writer.write { db in
            var clashQuery = EvaluationTemplateRecord.filter(Column("studentId") == studentId && Column("name") == name)
            if let id = template.id { clashQuery = clashQuery.filter(Column("id") != id) }   // `id != NULL` 在 SQL 里永远为假
            let clash = try clashQuery.fetchOne(db)
            if clash != nil { throw GxuError.invalidData("已经有叫「\(name)」的模板") }
            var record = EvaluationTemplateRecord(id: template.id, studentId: studentId, name: name, answersJSON: json, comment: template.comment, updatedAt: now)
            if template.id != nil {
                guard try EvaluationTemplateRecord.filter(Column("id") == template.id && Column("studentId") == studentId).fetchOne(db) != nil
                else { throw GxuError.invalidData("模板不存在") }
                try record.update(db)
            } else {
                try record.insert(db)
            }
            return Self.template(record)
        }
    }

    public func delete(id: Int64, studentId: String) async throws {
        try await database.writer.write { db in
            _ = try EvaluationTemplateRecord.filter(Column("id") == id && Column("studentId") == studentId).deleteAll(db)
        }
    }

    private static func template(_ r: EvaluationTemplateRecord) -> EvaluationTemplate {
        let answers = (try? JSONDecoder().decode([Int].self, from: Data(r.answersJSON.utf8))) ?? []
        return EvaluationTemplate(id: r.id, name: r.name, answers: answers, comment: r.comment, updatedAt: r.updatedAt)
    }
}
