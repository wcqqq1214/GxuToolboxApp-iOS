#if DEBUG
import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import Synchronization

/// 调试用演示数据：启动参数带 `-GxuDemo` 时，不连后端，用内置的假课表跑完整界面（截图自查用）。
@MainActor
enum DemoMode {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-GxuDemo") }
    /// `-GxuDemoOffline`：前两次请求（开学日 + 课表）成功，之后全部失败，用来看离线 / 刷新失败的状态
    static var simulatesOffline: Bool { ProcessInfo.processInfo.arguments.contains("-GxuDemoOffline") }

    static let services: AppServices = {
        let client = BackendClient(session: BackendClient.makeSession(configuration: .ephemeral))
        let credentials = InMemoryCredentialStore([.jw: Credential(username: "2025000000", password: "demo")])
        let jw = JwSessionManager(credentials: credentials, transport: client)
        return AppServices(
            backend: simulatesOffline ? OfflineAfterBackend(wrapped: DemoBackend(), allowedCalls: 2) : DemoBackend(),
            database: try! AppDatabase.inMemory(features: FeatureRegistry.migrations),
            shared: UserDefaultsSharedStore(suiteName: nil),
            accounts: AccountCenter(credentials: credentials, jw: jw, states: [.jw: .authenticated], studentId: "2025000000")
        )
    }()
}

private final class OfflineAfterBackend: BackendAPI {
    private let wrapped: any BackendAPI
    private let remaining: Mutex<Int>

    init(wrapped: any BackendAPI, allowedCalls: Int) {
        self.wrapped = wrapped
        self.remaining = Mutex(allowedCalls)
    }

    private func check() throws {
        let allowed = remaining.withLock { value -> Bool in
            guard value > 0 else { return false }
            value -= 1
            return true
        }
        if !allowed { throw GxuError.network("") }
    }

    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        try check()
        return try await wrapped.get(path, query: query, auth: auth, as: type)
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        try check()
        return try await wrapped.post(path, body: body, auth: auth, as: type)
    }
}

private struct DemoBackend: BackendAPI {
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        let body: String
        switch path {
        case "/jw/profile/startDay": body = Self.startDays
        case "/jw/schedule/personal": body = Self.schedule
        default: throw GxuError.network("演示模式不支持 \(path)")
        }
        return try JSONDecoder().decode(type, from: Data(#"{"data":\#(body)}"#.utf8))
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        guard path == "/jw/profile" else { throw GxuError.network("演示模式不支持 \(path)") }
        let profile = #"{"data":{"student_id":"2025000000","name":"演示同学","college":"土木建筑工程学院","major":"土木工程","class_name":"土木251","grade":"2025","study_years":"4"}}"#
        return try JSONDecoder().decode(type, from: Data(profile.utf8))
    }

    /// 今天落在第 6 周；再附一个已结束的上学期，用来试学期菜单
    private static var startDays: String {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)!.start   // 系统周从周日算，下面转成周一
        let monday = calendar.date(byAdding: .day, value: calendar.component(.weekday, from: weekStart) == 1 ? 1 : 0, to: weekStart)!
        let current = calendar.date(byAdding: .day, value: -5 * 7, to: monday)!
        let previous = calendar.date(byAdding: .day, value: -26 * 7, to: current)!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        let year = calendar.component(.year, from: current)
        return """
        [{"year": \(year), "term": 1, "day": "\(f.string(from: current))", "week": 18, "is_current": true},
         {"year": \(year - 1), "term": 2, "day": "\(f.string(from: previous))", "week": 18, "is_current": false}]
        """
    }

    private static let schedule = """
    {"practiceList": [{"courseName": "计算机网络原理实践", "time": "1-16周", "teacher": "教师丁"}],
     "theoryList": [
      \(course("高等数学", 1, "1-2", "1-16", "西3-406", "教师甲", building: "西三教"))
      \(course("程序设计基础", 1, "1-2", "1,3,5,7,9,11,13,15", "西3-501", "教师乙", building: "西三教"))
      \(course("高等数学", 3, "3-4", "1-16", "西3-406", "教师甲", building: "西三教"))
      \(course("大学英语", 2, "1-2", "1-16", "西2-302", "教师丙", building: "西二教"))
      \(course("数据结构", 2, "5-6", "1-16", "东1-201", "教师丁", building: "东一教"))
      \(course("数据结构", 4, "5-6", "1-16", "东1-201", "教师丁", building: "东一教"))
      \(course("线性代数", 4, "1-3", "1-12", "西3-407", "教师戊", building: "西三教"))
      \(course("大学物理实验", 3, "5-8", "3,5,7,9,11,13", "物理实验室", "教师己", building: "实验楼"))
      \(course("体育", 5, "3-4", "1-16", "西体育馆", "教师庚", building: "体育学院"))
      \(course("马克思主义基本原理", 5, "1-2", "1-16", "西2-101", "教师辛", building: "西二教"))
      \(course("计算机网络", 4, "7-8", "1-16", "东1-305", "教师壬", building: "东一教"))
      \(course("大学生心理健康", 3, "9-11", "1-8", "网络教室", "网络教师", building: ""))
      \(course("摄影艺术", 6, "5-6", "1-12", "艺术楼A201", "教师癸", building: "", last: true))
     ]}
    """

    private static func course(_ name: String, _ weekday: Int, _ sections: String, _ weeks: String, _ venue: String, _ teacher: String, building: String, last: Bool = false) -> String {
        let parts = sections.split(separator: "-").map { Int($0)! }
        let expanded = weeks.contains("-") ? Array(Int(weeks.split(separator: "-")[0])!...Int(weeks.split(separator: "-")[1])!) : weeks.split(separator: ",").map { Int($0)! }
        return """
        {"building": "\(building)", "venueName": "\(venue)", "sectionRange": "\(sections)", "begin": \(parts[0]), "end": \(parts[1]),
         "courseName": "\(name)", "weeks": \(expanded), "teacher": "\(teacher)", "credits": "3", "courseCategory": "专业必修",
         "examMethod": "考试", "weekday": \(weekday), "qqGroup": "", "enrollmentCount": 60, "seatCount": 80}\(last ? "" : ",")
        """
    }
}
#endif
