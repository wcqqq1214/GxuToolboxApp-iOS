import GxuAuth
import GxuFoundation
import Observation

@MainActor @Observable
final class JwAccountModel {
    var username = ""
    var password = ""
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    private let accounts: AccountCenter
    /// 教务和统一认证共用同一套"学号 + 密码"页面
    let system: AuthSystem

    init(accounts: AccountCenter, system: AuthSystem = .jw) {
        self.accounts = accounts
        self.system = system
    }

    var isSignedIn: Bool { accounts.states[system] != .noAccount }
    var studentId: String? { system == .jw ? accounts.studentId : accounts.savedUsername(system) }
    var canSubmit: Bool { !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isWorking }

    func submit() async {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await accounts.login(system, username: username, password: password)
            password = ""
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "登录失败，请稍后重试"
        }
    }

    func logout() async {
        await accounts.logout(system)
        username = ""
        password = ""
        errorMessage = nil
    }
}
