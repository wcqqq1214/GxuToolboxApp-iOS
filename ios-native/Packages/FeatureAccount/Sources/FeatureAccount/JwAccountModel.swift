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
        case .jw: "账号密码仅保存在本机钥匙串中，用于教务会话过期后自动重新登录。"
        case .oa: "账号密码仅保存在本机钥匙串中，用于登录 OA 文件系统和问卷系统，登录过期后自动重新登录。"
        default: "账号密码仅保存在本机钥匙串中，用于登录物理实验平台、工程训练中心等需要统一认证的服务。"
        }
    }

    /// 和设置首页同一个判断（`AuthState`）：只有「已登录」才显示已登录内容；未登录、需要重新登录都显示登录表单
    var state: AuthState { accounts.states[system] ?? .noAccount }
    var isSignedIn: Bool { !state.showsLoginForm }
    /// 服务器明确拒绝了保存的账号密码
    var needsRelogin: Bool { state == .signedOut }

    /// 需要重新登录时把保存的账号预填进表单（不预填密码）
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
