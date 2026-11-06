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
                            case "c-teacher-detail": TeacherDetailView(teacher: TeacherSummary(id: "1", name: "张明", unit: "计算机与电子信息学院", picURL: "http://prof.gxu.edu.cn/images/icon-teacher.jpg"))
                            case "c-teacher-leader": TeacherDetailView(teacher: .leader(SchoolLeaders.all[0].leaders[0]), leader: SchoolLeaders.all[0].leaders[0])
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
        case "/attendance/v2/personal": inner = Self.records
        case "/attendance/v2/schedule": inner = Self.schedule
        case "/teachers/search":
            return try JSONDecoder().decode(type, from: Data(Self.teacherSearch.utf8))
        case "/teachers/profile":
            // 学校领导的资料很少（真实响应也是这样：只有姓名、性别、职称、工号和更新时间）
            let json = query["school"] == "校领导" ? Self.leaderProfile : Self.teacherProfile
            return try JSONDecoder().decode(type, from: Data(json.utf8))
        default: throw GxuError.network("调试数据不支持 \(path)")
        }
        return try JSONDecoder().decode(type, from: Data(#"{"code":200,"data":\#(inner)}"#.utf8))
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("调试数据不支持 \(path)")
    }

    private static let teacherSearch = """
    {"data":{"list":[
      {"id":"1","name":"张明","unit":"计算机与电子信息学院","picUrl":"http://prof.gxu.edu.cn/images/icon-teacher.jpg"},{"id":"2","name":"张伟","unit":"土木建筑工程学院"},
      {"id":"3","name":"张丽","unit":"数学与信息科学学院","picUrl":""},{"id":"4","name":"张强","unit":"机械工程学院"}],"pages":3,"total":41}}
    """

    private static let leaderProfile = """
    {"data":{"baseInfo":{"name":"徐华蕊","sex":"2","title":"教授","pic":"","employed":"1","updatedAt":1775180200000,"supervisedDisciplines":[]},
     "academicProfile":{"employeeNumber":"90000001","biography":"","achievements":{"summary":"","papers":"","books":"","patents":""}}}}
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

    private static var records: String {
        func r(_ off: Int, _ name: String, _ room: String, _ range: String, _ label: String, _ code: Int, _ status: String) -> String {
            #"{"date":"\#(day(off))","courseName":"\#(name)","roomName":"\#(room)","periodRange":"\#(range)","periodLabel":"\#(label)","statusCode":\#(code),"statusName":"\#(status)"}"#
        }
        let wd = (Calendar.current.component(.weekday, from: .now) + 5) % 7   // 0 = 周一
        let list = [
            r(-wd + 3, "程序设计基础", "东1-201", "5,6", "第5-6节", 1, "正常"),
            r(-wd + 2, "大学英语", "西2-302", "3,4", "第3-4节", 2, "迟到"),
            r(-wd + 2, "大学物理实验", "实验楼B201", "7,8", "第7-8节", 4, "未到"),
            r(-wd, "高等数学", "西3-406", "1,2", "第1-2节", 1, "正常"),
            r(-12, "线性代数", "西3-407", "1,2,3", "第1-3节", 2, "迟到"),
            r(-20, "体育", "西体育馆", "3,4", "第3-4节", 1, "正常"),
        ]
        return #"{"items":[\#(list.joined(separator: ","))]}"#
    }

    /// 本周：周一 1–2 节高数、周三 3–4 节英语、周四 5–6 节程序设计
    private static var schedule: String {
        let weekday = (Calendar.current.component(.weekday, from: .now) + 5) % 7
        func date(_ d: Int) -> String { day(-weekday + d - 1) }
        func cell(_ d: Int, _ id: Int, _ name: String, _ room: String, _ a: Int, _ b: Int) -> String {
            #"{"date":"\#(date(d))","subjectId":\#(id),"subjectName":"\#(name)","periods":[\#(a),\#(b)],"connectedCount":1,"roomName":"\#(room)"}"#
        }
        // 周一 1–2 节高数，周三 3–4 节英语，周四 5–6 节程序设计（和上面的记录日期对得上，状态按 `<日期>-<节次>` 对应）
        let rows = [
            #"{"date":"\#(date(1))","courses":[\#(cell(1, 11, "高等数学", "西3-406", 1, 2))]}"#,
            #"{"date":"\#(date(3))","courses":[\#(cell(3, 12, "大学英语", "西2-302", 3, 4))]}"#,
            #"{"date":"\#(date(4))","courses":[\#(cell(4, 13, "程序设计基础", "东1-201", 5, 6))]}"#,
        ]
        return #"{"totalWeeks":20,"rows":[\#(rows.joined(separator: ","))]}"#
    }
}
#endif
