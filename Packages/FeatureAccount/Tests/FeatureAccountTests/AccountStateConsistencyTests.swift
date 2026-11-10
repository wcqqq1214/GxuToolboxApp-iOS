import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import Testing
@testable import FeatureAccount

/// 设置首页（`AuthState.displayText`）和账号详情页（`JwAccountModel` / `AttendanceAccountModel`）必须用同一个状态，不能矛盾
@MainActor
struct AccountStateConsistencyTests {
    private func center(_ state: AuthState, system: AuthSystem, studentId: String? = "2025001") -> AccountCenter {
        let services = AppServices.preview(signedIn: false)
        let creds = InMemoryCredentialStore([system: Credential(username: system == .jw ? (studentId ?? "") : "saved-user", password: "p")])
        let jw = JwSessionManager(credentials: creds, transport: BackendClient(session: BackendClient.makeSession(configuration: .ephemeral)))
        _ = services
        return AccountCenter(credentials: creds, jw: jw, states: [system: state], studentId: studentId)
    }

    @Test(arguments: [AuthSystem.jw, .unified, .oa])
    func detailPageAndHomeAgreeForEveryState(system: AuthSystem) {
        for state in [AuthState.noAccount, .authenticated, .signedOut] {
            let accounts = center(state, system: system)
            let model = JwAccountModel(accounts: accounts, system: system)
            // 首页显示 displayText；详情页是否显示已登录内容必须和它一致
            #expect(model.isSignedIn == (accounts.states[system]?.displayText == "已登录"), "\(system) \(state)")
            #expect(model.needsRelogin == (accounts.states[system]?.displayText == "需要重新登录"), "\(system) \(state)")
            #expect(model.isSignedIn == !state.showsLoginForm)
        }
    }

    @Test func needsReloginShowsTheFormWithTheSavedUsernamePrefilled() {
        let accounts = center(.signedOut, system: .jw)
        let model = JwAccountModel(accounts: accounts)
        #expect(!model.isSignedIn && model.needsRelogin)
        model.prefillUsernameIfNeeded()
        #expect(model.username == "2025001")
        #expect(model.password.isEmpty)               // 不预填密码
        // 未登录不预填
        let none = JwAccountModel(accounts: center(.noAccount, system: .jw, studentId: nil))
        none.prefillUsernameIfNeeded()
        #expect(none.username.isEmpty)
    }

    @Test func attendancePageFollowsTheSameState() {
        for state in [AuthState.noAccount, .authenticated, .signedOut] {
            let accounts = center(state, system: .attendance)
            let model = AttendanceAccountModel(accounts: accounts)
            #expect(model.isSignedIn == !state.showsLoginForm)
            #expect(model.needsRelogin == (state == .signedOut))
        }
        let model = AttendanceAccountModel(accounts: center(.signedOut, system: .attendance))
        model.prefillUsernameIfNeeded()
        #expect(model.username == "saved-user")
    }
}
