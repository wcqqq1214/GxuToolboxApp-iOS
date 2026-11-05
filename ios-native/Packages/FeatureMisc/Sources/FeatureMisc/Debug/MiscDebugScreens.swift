#if DEBUG
import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import SwiftUI

/// DEBUG：`-GxuScreen c-attendance | c-attendance-expired | c-attendance-nologin`，用内置假数据打开考勤页，截图自查用。
/// 有 `-GxuAttendanceSchedule` 时默认打开"考勤课表"页签（需要和 -GxuScreen 一起用）。
public enum MiscDebugScreens {
    public static func handles(_ name: String) -> Bool { name.hasPrefix("c-attendance") || name.hasPrefix("c-teacher") }

    @MainActor @ViewBuilder
    public static func view(for name: String) -> some View {
        PushedScreen(name: name)
    }

    /// 带返回按钮地"推"进去，和真实导航一致
    private struct PushedScreen: View {
        let name: String
        @State private var path = [String]()
        var body: some View {
            NavigationStack(path: $path) {
                Text("工具箱").navigationTitle("工具箱")
                    .navigationDestination(for: String.self) { page in
                        Group {
                            switch page {
                            case "c-teachers": TeacherSearchView()
                            case "c-teachers-results": TeacherSearchView()
                            case "c-teacher-detail": TeacherDetailView(teacher: TeacherSummary(id: "1", name: "张老师", unit: "计算机与电子信息学院"))
                            default: AttendanceView()
                            }
                        }
                        .environment(\.services, MiscDebugScreens.services(for: name))
                    }
            }
            .task { path = [name] }
        }
    }

    @MainActor
    static func services(for name: String) -> AppServices {
        let client = BackendClient(session: BackendClient.makeSession(configuration: .ephemeral))
        let credentials = InMemoryCredentialStore([.jw: Credential(username: "2025000000", password: "demo")])
        let jw = JwSessionManager(credentials: credentials, transport: client)
        let defaults = UserDefaults(suiteName: "gxu.debug.attendance")!
        defaults.set(try? JSONEncoder().encode(AttendanceLoginInfo.debug), forKey: "attendance.loginInfo")
        let attendance = AttendanceSession(transport: client, tokens: InMemoryTokenStore("debug"), defaults: defaults)
        let state: AuthState? = name == "c-attendance-expired" ? .signedOut : name == "c-attendance-nologin" ? nil : .authenticated
        var states: [AuthSystem: AuthState] = [.jw: .authenticated]
        if let state { states[.attendance] = state }
        return AppServices(
            backend: StubBackend(),
            database: try! AppDatabase.inMemory(features: []),
            shared: UserDefaultsSharedStore(suiteName: nil),
            accounts: AccountCenter(credentials: credentials, jw: jw, attendance: attendance, states: states, studentId: "2025000000")
        )
    }
}

private extension AttendanceLoginInfo {
    static var debug: AttendanceLoginInfo {
        // 没有公开构造器：经 JSON 往返
        try! JSONDecoder().decode(AttendanceLoginInfo.self, from: Data(#"{"userId":1,"userNo":"2025000000","userName":"演示同学","currentWeek":10}"#.utf8))
    }
}

private struct StubBackend: BackendAPI {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        let inner: String
        switch path {
        case "/attendance/index-data": inner = Self.menu
        case "/attendance/personal-data": inner = Self.records
        case "/attendance/schedule": inner = Self.schedule
        case "/teachers/search":
            return try JSONDecoder().decode(type, from: Data(Self.teacherSearch.utf8))
        case "/teachers/profile":
            return try JSONDecoder().decode(type, from: Data(Self.teacherProfile.utf8))
        default: throw GxuError.network("调试数据不支持 \(path)")
        }
        return try JSONDecoder().decode(type, from: Data(#"{"data":{"code":600,"msg":"","data":\#(inner)}}"#.utf8))
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("调试数据不支持 \(path)")
    }

    private static let teacherSearch = """
    {"data":{"list":[
      {"id":"1","name":"张明","unit":"计算机与电子信息学院"},{"id":"2","name":"张伟","unit":"土木建筑工程学院"},
      {"id":"3","name":"张丽","unit":"数学与信息科学学院"},{"id":"4","name":"张强","unit":"机械工程学院"}],"pages":3,"total":41}}
    """

    private static let teacherProfile = """
    {"data":{"baseInfo":{"name":"张明","title":"教授","highestDegree":"博士","highestEducation":"研究生","supervisor":"博士生导师","email":"zhang@example.edu.cn","telephone":"0771-0000000",
      "supervisedDisciplines":[{"disciplineCategory":"工学","primaryDiscipline":"计算机科学与技术","secondary":"计算机应用技术"}]},
     "academicProfile":{"biography":"长期从事分布式系统和教育信息化研究。","coursesTaught":"操作系统；计算机网络","researchDirections":"分布式系统；边缘计算",
      "achievements":{"papers":"发表论文 60 余篇。","books":"","patents":"授权发明专利 5 项。"},"honorsAndAwards":"自治区教学成果奖二等奖"}}}
    """

    private static func day(_ offset: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Calendar.current.date(byAdding: .day, value: offset, to: .now)!)
    }

    private static var menu: String {
        let year = Calendar.current.component(.month, from: .now) >= 9 ? Calendar.current.component(.year, from: .now) : Calendar.current.component(.year, from: .now) - 1
        // 第一周的周一 = 今天往前推到本周一再退 9 周
        let weekday = (Calendar.current.component(.weekday, from: .now) + 5) % 7
        return """
        {"calendarList":[
          {"calendarId":17,"calendarName":"\(year - 1)-2","firstWeekBegin":"\(day(-weekday - 63 - 140))","lastWeekEnd":"\(day(-weekday - 63 - 7))","weekTotal":20,"isCurrent":0},
          {"calendarId":18,"calendarName":"\(year)-1","firstWeekBegin":"\(day(-weekday - 63))","lastWeekEnd":"\(day(-weekday + 77))","weekTotal":20,"isCurrent":1}]}
        """
    }

    private static var records: String {
        func r(_ off: Int, _ name: String, _ room: String, _ periods: String, _ id: Int, _ label: String, _ time: String) -> String {
            #"{"day":"\#(day(off))","courseName":"\#(name)","roomName":"\#(room)","periodConnect":"\#(periods)","atdStateId":\#(id),"atdStateName":"\#(label)","atdTime":"\#(time.isEmpty ? "" : day(off) + " " + time)"}"#
        }
        let list = [
            r(0, "程序设计基础", "东1-201", "5-6", 1, "正常", "14:22:01"),
            r(-1, "大学英语", "西2-302", "3-4", 2, "迟到", "10:04:33"),
            r(-1, "大学物理实验", "实验楼B201", "7-8", 4, "未到", ""),
            r(-3, "高等数学", "西3-406", "1-2", 1, "正常", "07:52:10"),
            r(-2, "线性代数", "西3-407", "1-3", 1, "正常", "07:55:40"),
            r(-3, "体育", "西体育馆", "3-4", 100, "无需打卡", ""),
        ]
        return #"{"records":[\#(list.joined(separator: ","))],"total_record":41,"total_page":3,"page_index":1}"#
    }

    /// 本周：周一 1–2 节高数、周三 3–4 节英语、周四 5–6 节程序设计
    private static var schedule: String {
        let weekday = (Calendar.current.component(.weekday, from: .now) + 5) % 7
        func date(_ d: Int) -> String { day(-weekday + d - 1) }
        var rows: [[String]] = Array(repeating: Array(repeating: "{}", count: 8), count: 13)
        func put(_ row: Int, _ d: Int, _ name: String, _ connect: Int) {
            rows[row][d] = #"{"weekDay":"\#(date(d))","subjectName":"\#(name)","connectCount":\#(connect)}"#
        }
        put(0, 1, "高等数学", 1); put(1, 1, "高等数学", 0)
        put(2, 3, "大学英语", 1); put(3, 3, "大学英语", 0)
        put(4, 4, "程序设计基础", 1); put(5, 4, "程序设计基础", 0)
        let body = rows.map { #"{"courses":[\#($0.joined(separator: ","))]}"# }.joined(separator: ",")
        return #"{"resTableRankList":[\#(body)]}"#
    }
}
#endif
