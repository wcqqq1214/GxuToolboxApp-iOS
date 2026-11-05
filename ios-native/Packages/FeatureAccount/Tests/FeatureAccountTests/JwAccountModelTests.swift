import GxuAuth
import GxuFoundation
import GxuTestSupport
import Testing
@testable import FeatureAccount

@MainActor
struct JwAccountModelTests {
    @Test func submitIsDisabledUntilBothFieldsFilled() {
        let model = JwAccountModel(accounts: AppServices.preview(signedIn: false).accounts)
        #expect(!model.canSubmit)
        model.username = "2025001"
        #expect(!model.canSubmit)
        model.password = "pw"
        #expect(model.canSubmit)
    }

    @Test func failedLoginShowsChineseMessageAndKeepsInput() async {
        // preview 服务的后端没有任何可用会话，登录必然失败（离线/无响应）
        let model = JwAccountModel(accounts: AppServices.preview(signedIn: false).accounts)
        model.username = "1"
        model.password = "2"
        await model.submit()
        #expect(model.errorMessage != nil)
        #expect(!model.isSignedIn)
        #expect(model.password == "2")
    }

    @Test func signedInPreviewReportsStudentId() {
        let model = JwAccountModel(accounts: AppServices.preview(studentId: "123").accounts)
        #expect(model.isSignedIn)
        #expect(model.studentId == "123")
    }

    @Test func logoutResetsState() async {
        let model = JwAccountModel(accounts: AppServices.preview(studentId: "123").accounts)
        await model.logout()
        #expect(!model.isSignedIn)
        #expect(model.studentId == nil)
    }
}
