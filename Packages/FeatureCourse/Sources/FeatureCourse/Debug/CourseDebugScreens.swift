#if DEBUG
import ExamKit
import ExamUI
import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import ScheduleKit
import SwiftUI

public enum CourseDebugScreens {
    public static func handles(_ name: String) -> Bool { name.hasPrefix("c-") && !name.hasPrefix("c-attendance") && !name.hasPrefix("c-teacher") }

    @MainActor
    public static func view(for name: String) -> some View {
        PushedScreen(name: name)
    }

    private struct PushedScreen: View {
        let name: String
        @State private var path = [String]()

        var body: some View {
            NavigationStack(path: $path) {
                Text("工具箱").navigationTitle("工具箱")
                    .navigationDestination(for: String.self) { page(for: $0).environment(\.services, CourseDebugScreens.services) }
            }
            .task {
                if name == "c-evaluation-templates" {
                    let repo = EvaluationTemplateRepository(database: CourseDebugScreens.services.database)
                    _ = try? await repo.save(EvaluationTemplate(name: "全部满意", comment: "老师讲课认真，收获很大。"), studentId: "2025000000")
                    var mixed = EvaluationTemplate(name: "有选择地打分", answers: EvaluationQuestions.defaultAnswers)
                    mixed.answers[0] = 0; mixed.answers[1] = 0; mixed.answers[6] = 2
                    _ = try? await repo.save(mixed, studentId: "2025000000")
                }
                path = [name]
            }
        }

        @ViewBuilder
        private func page(for name: String) -> some View {
            switch name {
            case "c-exam": ExamInfoView()
            case "c-score": ScoreWithPendingView()
            case "c-gpa": GpaView()
            case "c-holiday": HolidayView()
            case "c-timeshift": TimeShiftView()
            case "c-selected": SelectedCoursesView()
            case "c-strategy": ElectiveStrategyView()
            case "c-evaluation": EvaluationOverviewView()
            case "c-evaluation-templates": EvaluationTemplatesView()
            default: Text("未知页面 \(name)")
            }
        }
    }

    @MainActor static let services: AppServices = {
        let client = BackendClient(session: BackendClient.makeSession(configuration: .ephemeral))
        let credentials = InMemoryCredentialStore([.jw: Credential(username: "2025000000", password: "demo")])
        let jw = JwSessionManager(credentials: credentials, transport: client)
        return AppServices(
            backend: StubBackend(),
            database: try! AppDatabase.inMemory(features: [ScheduleKit.migrations, ExamRepository.migrations, CourseFeature.migrations]),
            shared: UserDefaultsSharedStore(suiteName: nil),
            accounts: AccountCenter(credentials: credentials, jw: jw, states: [.jw: .authenticated], studentId: "2025000000")
        )
    }()
}

struct StubBackend: BackendAPI {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        let body: String
        switch path {
        case "/jw/profile/startDay": body = Self.startDays
        case "/jw/exam": body = Self.exams
        case "/jw/evaluation": body = Self.evaluation
        case "/jw/elective-progress": body = Self.electiveProgress
        case "/jw/score": body = query["year"] == nil ? Self.allScores : Self.scores
        case "/jw/selected-courses": body = Self.selected(year: query["year"].flatMap(Int.init), term: query["term"].flatMap(Int.init))
        case "/jw/score/usual": body = #"[{"name":"平时成绩","ratio":"30","score":"91"},{"name":"期末成绩","ratio":"70","score":"84"},{"name":"总评","ratio":"N/A","score":"86"}]"#
        default: throw GxuError.network("调试数据不支持 \(path)")
        }
        return try JSONDecoder().decode(type, from: Data(#"{"data":\#(body)}"#.utf8))
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        guard path == "/jw/profile" else { throw GxuError.network("调试数据不支持 \(path)") }
        let profile = #"{"data":{"student_id":"2025000000","name":"演示同学","college":"计算机与电子信息学院","major":"计算机科学与技术","class_name":"计科251","grade":"2025","study_years":"4"}}"#
        return try JSONDecoder().decode(type, from: Data(profile.utf8))
    }

    private static let electiveProgress = #"""
    {"studentId":"2025000000","grade":2025,"ruleId":"demo","ruleVersion":"1","ruleName":"2025级通识选修要求（演示）",
     "computedAt":"2026-11-05T08:30:00.000Z","complete":false,
     "stats":{"totalCredits":6,"offlineCredits":4,"modules":{"lead":{"credits":0,"courseCount":0},"entrepreneurship":{"credits":0,"courseCount":0},"art":{"credits":2,"courseCount":1},"asean":{"credits":0,"courseCount":0},"ethnic":{"credits":0,"courseCount":0},"ocean":{"credits":4,"courseCount":2}}},
     "requirements":[{"key":"total","label":"通识选修总学分","actual":6,"required":8,"operator":"gte","unit":"credits","passed":false},{"key":"online","label":"网课学分占比","actual":0.333,"required":0.5,"operator":"lte","unit":"ratio","passed":true},{"key":"modules","label":"覆盖模块","actual":2,"required":2,"operator":"gte","unit":"modules","passed":true}],
     "remainingRequired":["艺术鉴赏"],
     "courses":[{"courseId":"c1","courseName":"海洋科学导论","classIds":["j1"],"locations":["东校区"],"teachers":["甲老师"],"modules":["ocean"],"online":false,"credit":2,"score":88,"status":"passed","counted":true,"countedCredits":2,"attempts":[]},
       {"courseId":"c2","courseName":"音乐欣赏","classIds":["j2"],"locations":[],"teachers":[],"modules":["art"],"online":true,"credit":2,"score":null,"status":"pending","counted":false,"countedCredits":0,"attempts":[]},
       {"courseId":"c3","courseName":"中国传统文化","classIds":["j3"],"locations":[],"teachers":[],"modules":[],"online":null,"credit":null,"score":null,"status":"review","counted":false,"countedCredits":0,"excludedReason":"缺少学分","attempts":[]}],
     "issues":[{"code":"missing-credit","courseId":"c3","classId":"j3","message":"缺少学分"}],"isQualified":null}
    """#

    private static var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }

    private static func day(_ offset: Int) -> String { dayFormatter.string(from: Calendar.current.date(byAdding: .day, value: offset, to: .now)!) }

    private static var startDays: String {
        let year = Calendar.current.component(.month, from: .now) >= 9 ? Calendar.current.component(.year, from: .now) : Calendar.current.component(.year, from: .now) - 1
        return #"[{"year": \#(year), "term": 1, "day": "\#(day(-60))", "week": 18, "is_current": true}]"#
    }

    private static var exams: String {
        """
        [{"id": "e1", "course": "高等数学", "classroom": "西3-406", "time": "\(day(0))(23:00-23:59)", "type": "2026-2027学年第一学期期末考试"},
         {"id": "e2", "course": "大学英语", "classroom": "西2-302", "time": "\(day(5))(14:30-16:30)", "type": "2026-2027学年第一学期期末考试"},
         {"id": "e3", "course": "程序设计基础", "classroom": "东1-201", "time": "\(day(9))(09:00-11:00)", "type": "2026-2027学年第一学期期末考试"},
         {"id": "e4", "course": "体育", "classroom": "", "time": "待定", "type": "2026-2027学年第一学期期末考试"},
         {"id": "e5", "course": "大学物理实验", "classroom": "实验楼 B201", "time": "\(day(-10))(09:00-11:00)", "type": "2026-2027学年第一学期期中考试"}]
        """
    }

    private static var evaluation: String {
        func t(_ teacher: String, _ course: String, _ type: String, _ status: String, _ id: String) -> String {
            #"{"teacherName":"\#(teacher)","courseName":"\#(course)","courseTypeName":"\#(type)","submitStatus":"\#(status)","teachingClassId":"\#(id)","courseId":"c\#(id)"}"#
        }
        return "[" + [
            t("教师甲", "高等数学", "理论", "已评完", "1"), t("教师丙", "大学英语", "理论", "未评", "2"),
            t("教师乙", "程序设计基础", "理论", "未评完", "3"), t("教师己", "大学物理实验", "实验", "未评", "4"),
            t("教师戊", "线性代数", "理论", "已评完", "5"),
        ].joined(separator: ",") + "]"
    }

    private static func yearNow() -> Int { Calendar.current.component(.month, from: .now) >= 9 ? Calendar.current.component(.year, from: .now) : Calendar.current.component(.year, from: .now) - 1 }

    private static func selected(year only: Int?, term onlyTerm: Int?) -> String {
        let y = yearNow()
        func c(_ id: String, _ name: String, _ credit: String, _ system: String, _ kind: String, year: Int, term: Int, teacher: String = "教师甲", belong: String = "") -> (year: Int, term: Int, json: String) {
            (year, term, #"{"classId":"\#(id)","courseId":"k\#(id)","courseName":"\#(name)","type":"理论","selectionType":"\#(kind)","classification":"","belongTo":"\#(belong)","system":"\#(system)","teacher":"\#(teacher)","teacherId":"","credit":\#(credit),"year":\#(year),"term":\#(term)}"#)
        }
        let all = [
            c("s1", "高等数学", "5", "", "专业必修课", year: y, term: 1),
            c("s2", "大学英语", "3", "", "专业必修课", year: y, term: 1, teacher: "教师丙"),
            c("s3", "程序设计基础", "3.5", "", "专业必修课", year: y, term: 1, teacher: "教师乙"),
            c("s6", "大学物理实验", "1.5", "", "专业必修课", year: y, term: 1, teacher: "教师己"),
            c("s7", "摄影艺术", "2", "艺术与审美", "通识选修课", year: y, term: 1, teacher: "教师癸"),
            c("s8", "创新创业基础", "2", "创业", "通识选修课", year: y - 1, term: 2, teacher: "网络教师", belong: "网络通识"),
            c("s9", "海洋生态概论", "1", "亚热带与海洋生态", "通识选修课", year: y - 1, term: 2),
            c("s10", "科技伦理", "1", "科技与伦理", "通识选修课", year: y - 1, term: 1),
        ]
        let hit = all.filter { (only == nil || $0.year == only) && (onlyTerm == nil || $0.term == onlyTerm) }
        return "{\"items\":[" + hit.map(\.json).joined(separator: ",") + "]}"
    }

    private static var allScores: String {
        let y = yearNow()
        func item(_ id: String, _ term: Int, _ year: Int, _ name: String, _ credit: String, _ score: String) -> String {
            #"{"id":"\#(id)","year":\#(year),"term":\#(term),"course_name":"\#(name)","credit":\#(credit),"score":\#(score),"teacher_name":"教师","upload_at":"\#(day(-3)) 10:21:00"}"#
        }
        return "{\"items\":[" + [
            item("s7", 1, y, "摄影艺术", "2", "88"),
            item("s8", 2, y - 1, "创新创业基础", "2", "92"),
            item("s9", 2, y - 1, "海洋生态概论", "1", "59"),
            item("s10", 1, y - 1, "科技伦理", "1", "81"),
            item("s9b", 1, y, "海洋生态概论", "1", "75"),
        ].joined(separator: ",") + "]}"
    }

    private static var scores: String {
        let year = Calendar.current.component(.month, from: .now) >= 9 ? Calendar.current.component(.year, from: .now) : Calendar.current.component(.year, from: .now) - 1
        func item(_ id: String, _ term: Int, _ name: String, _ credit: String, _ score: String, _ teacher: String, _ at: String) -> String {
            #"{"id":"\#(id)","year":\#(year),"term":\#(term),"course_name":"\#(name)","credit":\#(credit),"score":\#(score),"teacher_name":"\#(teacher)","upload_at":"\#(at)"}"#
        }
        return "{\"items\":[" + [
            item("s1", 1, "高等数学", "5", "91", "教师甲", "\(day(-3)) 10:21:00"),
            item("s2", 1, "大学英语", "3", "78", "教师丙", "\(day(-4)) 16:02:11"),
            item("s3", 1, "程序设计基础", "3.5", "58", "教师乙", "\(day(-6)) 09:40:30"),
            item("s4", 1, "线性代数", "3", "86.5", "教师戊", "\(day(-8)) 14:12:00"),
            item("s5", 1, "体育", "1", "95", "教师庚", "\(day(-9)) 18:30:00"),
        ].joined(separator: ",") + "]}"
    }
}
#endif
