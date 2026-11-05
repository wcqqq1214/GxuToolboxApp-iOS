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

/// DEBUG：`-GxuScreen c-exam|c-score|c-gpa|c-holiday|c-timeshift|…`，用内置假数据（不连后端、不用账号）打开 C 负责的页面，截图自查用。
public enum CourseDebugScreens {
    public static func handles(_ name: String) -> Bool { name.hasPrefix("c-") }

    @MainActor @ViewBuilder
    public static func view(for name: String) -> some View {
        NavigationStack {
            switch name {
            case "c-exam": ExamInfoView()
            case "c-score": ScoreView()
            case "c-gpa": GpaView()
            case "c-holiday": HolidayView()
            case "c-timeshift": TimeShiftView()
            default: Text("未知页面 \(name)")
            }
        }
        .environment(\.services, services)
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

/// 按路径返回固定 JSON；时间相对"现在"
struct StubBackend: BackendAPI {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        let body: String
        switch path {
        case "/jw/profile/startDay": body = Self.startDays
        case "/jw/exam": body = Self.exams
        case "/jw/score": body = Self.scores
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
