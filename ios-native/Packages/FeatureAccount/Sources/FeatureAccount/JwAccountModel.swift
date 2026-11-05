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

    init(accounts: AccountCenter) {
        self.accounts = accounts
    }

    var isSignedIn: Bool { accounts.states[.jw] != .noAccount }
    var studentId: String? { accounts.studentId }
    var canSubmit: Bool { !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isWorking }

    func submit() async {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await accounts.login(.jw, username: username, password: password)
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
        await accounts.logout(.jw)
        username = ""
        password = ""
        errorMessage = nil
    }
}
