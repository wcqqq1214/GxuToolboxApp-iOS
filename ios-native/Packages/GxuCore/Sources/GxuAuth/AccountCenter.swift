import Foundation
import GxuFoundation
import Observation

@MainActor @Observable
public final class AccountCenter {
    public private(set) var states: [AuthSystem: AuthState]
    /// 当前教务账号学号，用于数据隔离
    public private(set) var studentId: String?

    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let jw: JwSessionManager
    @ObservationIgnored public let attendance: AttendanceSession?

    /// 教务（Cookie）和考勤（token）已接入；CA / OA 在后续步骤接入。
    public init(credentials: any CredentialStore, jw: JwSessionManager, attendance: AttendanceSession? = nil) {
        self.credentials = credentials
        self.jw = jw
        self.attendance = attendance
        var states = Dictionary(uniqueKeysWithValues: AuthSystem.allCases.map { ($0, AuthState.noAccount) })
        if let credential = credentials.load(.jw) {
            studentId = credential.username
            // 有 Cookie 就先乐观认为已登录；真正过期时由 BackendClient 自动重登
            states[.jw] = jw.hasSession() ? .authenticated : .signedOut
        }
        if attendance?.hasToken == true { states[.attendance] = .authenticated }
        else if attendance != nil, credentials.load(.attendance) != nil { states[.attendance] = .signedOut }
        self.states = states
        attendance?.setObserver { [weak self] state in
            Task { @MainActor in self?.states[.attendance] = state }
        }
        Task { [weak self] in
            await jw.setObserver { state in
                Task { @MainActor in self?.states[.jw] = state }
            }
        }
    }

    /// 预览 / 测试用：直接指定状态
    public init(credentials: any CredentialStore, jw: JwSessionManager, attendance: AttendanceSession? = nil, states: [AuthSystem: AuthState], studentId: String?) {
        self.credentials = credentials
        self.jw = jw
        self.attendance = attendance
        self.states = Dictionary(uniqueKeysWithValues: AuthSystem.allCases.map { ($0, states[$0] ?? .noAccount) })
        self.studentId = studentId
    }

    public func login(_ system: AuthSystem, username: String, password: String) async throws {
        guard system == .jw else {
            throw GxuError.invalidData(system == .attendance ? "考勤系统登录需要验证码，请使用 loginAttendance" : "\(system.displayName)暂未支持")
        }
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, !password.isEmpty else { throw GxuError.invalidData("请输入学号和密码") }
        try await jw.login(username: username, password: password)
        try credentials.save(Credential(username: username, password: password), for: .jw)
        studentId = username
        states[.jw] = .authenticated
    }

    /// 获取考勤登录验证码（图片 + ticket）
    public func attendanceCaptcha() async throws -> AttendanceCaptcha {
        guard let attendance else { throw GxuError.invalidData("考勤系统未配置") }
        return try await attendance.captcha()
    }

    /// 考勤登录。成功后保存账号（Keychain）和 token，状态变为 `.authenticated`；验证码错误等会抛 `GxuError.invalidData(服务端文案)`。
    public func loginAttendance(username: String, password: String, captcha: String, ticket: String?) async throws {
        guard let attendance else { throw GxuError.invalidData("考勤系统未配置") }
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let captcha = captcha.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, !password.isEmpty else { throw GxuError.invalidData("请输入账号和密码") }
        guard !captcha.isEmpty else { throw GxuError.invalidData("请输入验证码") }
        try await attendance.login(username: username, password: password, captcha: captcha, ticket: ticket)
        try credentials.save(Credential(username: username, password: password), for: .attendance)
        states[.attendance] = .authenticated
    }

    public func logout(_ system: AuthSystem) async {
        if system == .jw {
            await jw.logout()
            studentId = nil
        }
        if system == .attendance { attendance?.clear() }
        credentials.delete(system)
        states[system] = .noAccount
    }

    /// 失败时抛 `GxuError`
    public func ensureAuthenticated(_ system: AuthSystem) async throws {
        switch states[system] ?? .noAccount {
        case .authenticated: return
        case .noAccount: throw GxuError.notLoggedIn(system)
        case .signedOut:
            guard system == .jw else { throw GxuError.sessionExpired(system) }   // 考勤等需要用户交互（验证码）
            try await jw.renew(.jw)
            states[.jw] = .authenticated
        }
    }
}
