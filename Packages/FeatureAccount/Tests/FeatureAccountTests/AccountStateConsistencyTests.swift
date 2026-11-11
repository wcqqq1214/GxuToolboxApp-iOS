import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import Testing
@testable import FeatureAccount

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
        #expect(model.password.isEmpty)
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
