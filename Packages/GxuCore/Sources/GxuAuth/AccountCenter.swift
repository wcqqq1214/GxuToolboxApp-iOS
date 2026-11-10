import Foundation
import GxuFoundation
import Observation

@MainActor @Observable
public final class AccountCenter {
    public private(set) var states: [AuthSystem: AuthState]
    /// 当前教务账号学号，用于数据隔离
    public private(set) var studentId: String?
    public private(set) var unifiedUsername: String?

    @ObservationIgnored private var unifiedChange = UUID()

    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let jw: JwSessionManager
    @ObservationIgnored public let attendance: AttendanceSession?
    /// 统一认证（CA）会话，以及 PEC / 工程训练中心的 SSO 入口
    @ObservationIgnored public let unified: UnifiedAuthSession?
    /// OA 文件系统会话；问卷系统（wjxt）与 OA 共用 `.oa` 账号
    @ObservationIgnored public let oa: OASession?
    @ObservationIgnored public let wjxt: WjxtSession?
    /// 登录成功后的回调（埋点等）；由组装处设置
    @ObservationIgnored public var onLogin: (@MainActor (AuthSystem) -> Void)?

    /// 教务（Cookie）和考勤（token）已接入；CA / OA 在后续步骤接入。
    public init(credentials: any CredentialStore, jw: JwSessionManager, attendance: AttendanceSession? = nil, unified: UnifiedAuthSession? = nil, oa: OASession? = nil, wjxt: WjxtSession? = nil) {
        self.credentials = credentials
        self.unifiedUsername = credentials.load(.unified)?.username
        self.jw = jw
        self.attendance = attendance
        self.unified = unified
        self.oa = oa
        self.wjxt = wjxt
        var states = Dictionary(uniqueKeysWithValues: AuthSystem.allCases.map { ($0, AuthState.noAccount) })
        var needsSilentRenew = false
        if let credential = credentials.load(.jw) {
            studentId = credential.username
            // 有保存的账号就是「已登录」：会话 Cookie 缺失（例如重装后）不算退出，也不打扰用户。
            // 启动时没有 Cookie 就静默续期一次（见下）；之后过期由 BackendClient 自动重登
            states[.jw] = .authenticated
            needsSilentRenew = !jw.hasSession()
        }
        // 考勤：有 token = 已登录；账号还在但 token 没了（401 清掉的）= 需要重新登录（要输验证码，没法静默续期）
        if attendance?.hasToken == true { states[.attendance] = .authenticated }
        else if attendance != nil, credentials.load(.attendance) != nil { states[.attendance] = .signedOut }
        // CA 没有长期 token：有账号就是「已登录」，服务登录时会用 Keychain 里的账号重新登录；服务器明确拒绝时才变成需要重新登录
        if unified != nil, credentials.load(.unified) != nil { states[.unified] = .authenticated }
        // OA 同理：有账号就是「已登录」，请求时按需登录
        if oa != nil, credentials.load(.oa) != nil { states[.oa] = .authenticated }
        self.states = states
        attendance?.setObserver { [weak self] state in
            Task { @MainActor in self?.applyObserved(.attendance, state) }
        }
        if let oa {
            Task { [weak self] in
                await oa.setObserver { state in Task { @MainActor in self?.applyObserved(.oa, state) } }
            }
        }
        if let unified {
            Task { [weak self, unified] in
                await unified.setObserver { [weak unified] state, generation in
                    Task { @MainActor in
                        guard unified?.isCurrent(generation) == true else { return }
                        self?.applyObserved(.unified, state)
                    }
                }
            }
        }
        Task { [weak self] in
            await jw.setObserver { state in
                Task { @MainActor in self?.applyObserved(.jw, state) }
            }
            // 启动时有账号但没有会话：静默续期一次。成功 → 观察者置为已登录；服务器明确拒绝 → 需要重新登录；
            // 断网、超时、5xx 等其他错误什么都不改（状态保持已登录，下次请求自动重连）
            if needsSilentRenew { try? await jw.renew(.jw) }
        }
    }

    /// 会话层的状态通知。已经退出（`noAccount`）的账号不能被迟到的通知改回来
    private func applyObserved(_ system: AuthSystem, _ state: AuthState) {
        guard states[system] != .noAccount else { return }
        if system == .jw, studentId == nil { return }
        if system == .attendance, state == .signedOut, attendance?.hasToken == true { return }
        states[system] = state
    }

    /// 预览 / 测试用：直接指定状态
    public init(credentials: any CredentialStore, jw: JwSessionManager, attendance: AttendanceSession? = nil, unified: UnifiedAuthSession? = nil, oa: OASession? = nil, wjxt: WjxtSession? = nil, states: [AuthSystem: AuthState], studentId: String?) {
        self.credentials = credentials
        self.unifiedUsername = credentials.load(.unified)?.username
        self.jw = jw
        self.attendance = attendance
        self.unified = unified
        self.oa = oa
        self.wjxt = wjxt
        self.states = Dictionary(uniqueKeysWithValues: AuthSystem.allCases.map { ($0, states[$0] ?? .noAccount) })
        self.studentId = studentId
    }

    public func login(_ system: AuthSystem, username: String, password: String) async throws {
        if system == .unified {
            guard let unified else { throw GxuError.invalidData("统一认证未配置") }
            let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !username.isEmpty, !password.isEmpty else { throw GxuError.invalidData("请输入统一认证账号和密码") }
            let change = UUID()
            unifiedChange = change
            try await unified.login(username: username, password: password)
            guard unifiedChange == change else { throw CancellationError() }
            try credentials.save(Credential(username: username, password: password), for: .unified)
            unifiedUsername = username
            states[.unified] = .authenticated
            return
        }
        if system == .oa {
            guard let oa else { throw GxuError.invalidData("OA 系统未配置") }
            let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !username.isEmpty, !password.isEmpty else { throw GxuError.invalidData("请输入 OA 账号和密码") }
            try await oa.login(username: username, password: password)
            try credentials.save(Credential(username: username, password: password), for: .oa)
            await wjxt?.clear()   // 换账号时不能留着上一个账号的问卷系统会话
            states[.oa] = .authenticated
            return
        }
        guard system == .jw else {
            throw GxuError.invalidData(system == .attendance ? "考勤系统登录需要验证码，请使用 loginAttendance" : "\(system.displayName)暂未支持")
        }
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, !password.isEmpty else { throw GxuError.invalidData("请输入学号和密码") }
        try await jw.login(username: username, password: password)
        try credentials.save(Credential(username: username, password: password), for: .jw)
        studentId = username
        states[.jw] = .authenticated
        onLogin?(.jw)
    }

    /// 已保存账号的用户名（教务用 `studentId`；统一认证等从 Keychain 读）
    public func savedUsername(_ system: AuthSystem) -> String? {
        credentials.load(system)?.username
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
        if system == .unified {
            unifiedChange = UUID()
            credentials.delete(.unified)
            unifiedUsername = nil
            states[.unified] = .noAccount
            await unified?.logout()
            return
        }
        credentials.delete(system)
        if system == .oa {
            await oa?.clear()
            await wjxt?.clear()
        }
        states[system] = .noAccount
    }

    /// 失败时抛 `GxuError`。「需要重新登录」（服务器明确拒绝过账号密码 / 考勤 token 失效）不再自动重试，直接让用户去重新登录。
    public func ensureAuthenticated(_ system: AuthSystem) async throws {
        switch states[system] ?? .noAccount {
        case .authenticated: return
        case .noAccount: throw GxuError.notLoggedIn(system)
        case .signedOut: throw GxuError.sessionExpired(system)
        }
    }
}
