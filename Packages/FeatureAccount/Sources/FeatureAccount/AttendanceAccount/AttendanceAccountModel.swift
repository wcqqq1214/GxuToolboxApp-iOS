import GxuAuth
import GxuFoundation
import Observation
import UIKit

@MainActor @Observable
final class AttendanceAccountModel {
    var username = ""
    var password = ""
    var captchaCode = ""
    private(set) var captchaImage: UIImage?
    private(set) var isWorking = false
    private(set) var isLoadingCaptcha = false
    private(set) var errorMessage: String?

    private var ticket: String?
    private let accounts: AccountCenter

    init(accounts: AccountCenter) {
        self.accounts = accounts
    }

    /// 和设置首页同一个判断（`AuthState`）
    var isSignedIn: Bool { !(accounts.states[.attendance] ?? .noAccount).showsLoginForm }
    var needsRelogin: Bool { accounts.states[.attendance] == .signedOut }
    var displayName: String? {
        guard let info = accounts.attendance?.loginInfo else { return nil }
        return [info.userName, info.userNo].compactMap { $0 }.joined(separator: " · ")
    }
    var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
            && !captchaCode.trimmingCharacters(in: .whitespaces).isEmpty && !isWorking
    }

    /// 需要重新登录时预填保存的账号
    func prefillUsernameIfNeeded() {
        if needsRelogin, username.isEmpty, let saved = accounts.savedUsername(.attendance) { username = saved }
    }

    func loadCaptcha() async {
        isLoadingCaptcha = true
        defer { isLoadingCaptcha = false }
        captchaCode = ""
        do {
            let captcha = try await accounts.attendanceCaptcha()
            ticket = captcha.ticket
            if let text = captcha.text, !text.isEmpty { captchaCode = text }   // v2 后端随验证码返回文字，RN 同样自动填充
            captchaImage = captcha.imageData.flatMap(UIImage.init(data:))
            if captchaImage == nil { errorMessage = "验证码图片无法显示，请点击刷新" }
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "获取验证码失败"
        }
    }

    func submit() async {
        guard canSubmit else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await accounts.loginAttendance(username: username, password: password, captcha: captchaCode, ticket: ticket)
            password = ""
            captchaCode = ""
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            errorMessage = error.userMessage
            await loadCaptcha()   // 验证码一次性，失败后换一张
        } catch {
            errorMessage = "登录失败，请稍后重试"
            await loadCaptcha()
        }
    }

    func logout() async {
        await accounts.logout(.attendance)
        username = ""
        password = ""
        captchaCode = ""
        errorMessage = nil
        await loadCaptcha()
    }
}
