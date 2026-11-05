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

    /// Phase 1 只支持教务账号；其他系统在 Phase 2 接入。
    public init(credentials: any CredentialStore, jw: JwSessionManager) {
        self.credentials = credentials
        self.jw = jw
        var states = Dictionary(uniqueKeysWithValues: AuthSystem.allCases.map { ($0, AuthState.noAccount) })
        if let credential = credentials.load(.jw) {
            studentId = credential.username
            // 有 Cookie 就先乐观认为已登录；真正过期时由 BackendClient 自动重登
            states[.jw] = jw.hasSession() ? .authenticated : .signedOut
        }
        self.states = states
        Task { [weak self] in
            await jw.setObserver { state in
                Task { @MainActor in self?.states[.jw] = state }
            }
        }
    }

    /// 预览 / 测试用：直接指定状态
    public init(credentials: any CredentialStore, jw: JwSessionManager, states: [AuthSystem: AuthState], studentId: String?) {
        self.credentials = credentials
        self.jw = jw
        self.states = Dictionary(uniqueKeysWithValues: AuthSystem.allCases.map { ($0, states[$0] ?? .noAccount) })
        self.studentId = studentId
    }

    public func login(_ system: AuthSystem, username: String, password: String) async throws {
        guard system == .jw else { throw GxuError.invalidData("\(system.displayName)暂未支持") }
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, !password.isEmpty else { throw GxuError.invalidData("请输入学号和密码") }
        try await jw.login(username: username, password: password)
        try credentials.save(Credential(username: username, password: password), for: .jw)
        studentId = username
        states[.jw] = .authenticated
    }

    public func logout(_ system: AuthSystem) async {
        if system == .jw {
            await jw.logout()
            studentId = nil
        }
        credentials.delete(system)
        states[system] = .noAccount
    }

    /// 失败时抛 `GxuError`
    public func ensureAuthenticated(_ system: AuthSystem) async throws {
        switch states[system] ?? .noAccount {
        case .authenticated: return
        case .noAccount: throw GxuError.notLoggedIn(system)
        case .signedOut:
            guard system == .jw else { throw GxuError.sessionExpired(system) }
            try await jw.renew(.jw)
            states[.jw] = .authenticated
        }
    }
}
