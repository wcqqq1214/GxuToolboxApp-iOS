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
    let system: AuthSystem

    init(accounts: AccountCenter, system: AuthSystem = .jw) {
        self.accounts = accounts
        self.system = system
    }

    var title: String {
        switch system { case .jw: "教务账号"; case .oa: "OA 账号"; default: "统一认证账号" }
    }
    var usernamePrompt: String {
        switch system { case .jw: "学号"; case .oa: "OA 账号"; default: "统一认证账号" }
    }
    var passwordPrompt: String {
        switch system { case .jw: "教务系统密码"; case .oa: "OA 密码"; default: "统一认证密码" }
    }
    var usernameLabel: String { system == .jw ? "学号" : "账号" }
    var footer: String {
        switch system {
        case .jw: "账号密码保存在本机钥匙串中，用于自动重新登录。登录时会通过 HTTPS 将学号和密码发送至第三方代理服务器 api.tool.gxutech.xyz，由其代为访问学校教务系统。"
        case .oa: "账号密码保存在本机钥匙串中，登录时直接发送至学校 OA 或问卷系统，用于登录及会话过期后自动重新登录。"
        default: "账号密码保存在本机钥匙串中，登录时直接发送至学校统一认证系统，用于访问物理实验平台、工程训练中心等服务。"
        }
    }

    var state: AuthState { accounts.states[system] ?? .noAccount }
    var isSignedIn: Bool { !state.showsLoginForm }
    var needsRelogin: Bool { state == .needsRelogin }

    func prefillUsernameIfNeeded() {
        if needsRelogin, username.isEmpty, let saved = studentId { username = saved }
    }
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
