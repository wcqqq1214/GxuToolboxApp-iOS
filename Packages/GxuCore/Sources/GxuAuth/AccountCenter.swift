import Foundation
import GxuFoundation
import Observation

@MainActor @Observable
public final class AccountCenter {
    public private(set) var states: [AuthSystem: AuthState]
    public private(set) var studentId: String?
    public private(set) var jwSessionID = UUID()
    public private(set) var unifiedUsername: String?

    @ObservationIgnored private var unifiedChange = UUID()

    @ObservationIgnored private let credentials: any CredentialStore
    @ObservationIgnored private let jw: JwSessionManager
    @ObservationIgnored public let attendance: AttendanceSession?
    @ObservationIgnored public let unified: UnifiedAuthSession?
    @ObservationIgnored public let oa: OASession?
    @ObservationIgnored public let wjxt: WjxtSession?
    @ObservationIgnored public var onLogin: (@MainActor (AuthSystem) -> Void)?

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
            states[.jw] = .authenticated
            needsSilentRenew = !jw.hasSessionCookie()
        }
        if attendance?.hasToken == true { states[.attendance] = .authenticated }
        else if attendance != nil, credentials.load(.attendance) != nil { states[.attendance] = .needsRelogin }
        if unified != nil, credentials.load(.unified) != nil { states[.unified] = .authenticated }
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
            if needsSilentRenew { try? await jw.renew(.jw) }
        }
    }

    private func applyObserved(_ system: AuthSystem, _ state: AuthState) {
        guard states[system] != .noAccount else { return }
        if system == .jw, studentId == nil { return }
        if system == .attendance, state == .needsRelogin, attendance?.hasToken == true { return }
        states[system] = state
    }

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
            await wjxt?.clear()
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
        jwSessionID = UUID()
        studentId = username
        states[.jw] = .authenticated
        onLogin?(.jw)
    }

    public func savedUsername(_ system: AuthSystem) -> String? {
        credentials.load(system)?.username
    }

    public func attendanceCaptcha() async throws -> AttendanceCaptcha {
        guard let attendance else { throw GxuError.invalidData("考勤系统未配置") }
        return try await attendance.captcha()
    }

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
            studentId = nil
            jwSessionID = UUID()
            await jw.logout()
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

    public func requireAuthenticatedState(_ system: AuthSystem) async throws {
        switch states[system] ?? .noAccount {
        case .authenticated: return
        case .noAccount: throw GxuError.notLoggedIn(system)
        case .needsRelogin: throw GxuError.sessionExpired(system)
        }
    }
}
