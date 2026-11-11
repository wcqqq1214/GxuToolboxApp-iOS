#if DEBUG
import Foundation
import GxuAuth
import GxuFoundation

enum DebugAutoLogin {
    @MainActor
    static func runIfRequested(_ accounts: AccountCenter) async {
        let env = ProcessInfo.processInfo.environment
        guard let user = env["GXU_TEST_USER"], let pass = env["GXU_TEST_PASS"], !user.isEmpty, !pass.isEmpty else { return }
        if accounts.studentId == user, accounts.states[.jw] == .authenticated {
            NSLog("[DebugAutoLogin] 已登录，跳过")
            return
        }
        do {
            try await accounts.login(.jw, username: user, password: pass)
            NSLog("[DebugAutoLogin] 登录成功")
        } catch let error as GxuError {
            NSLog("[DebugAutoLogin] 登录失败：%@", error.userMessage)
        } catch {
            NSLog("[DebugAutoLogin] 登录失败")
        }
    }
}
#endif
