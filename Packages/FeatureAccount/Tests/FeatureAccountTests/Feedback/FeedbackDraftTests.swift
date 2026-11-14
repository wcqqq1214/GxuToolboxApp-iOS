import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuTestSupport
import Testing
@testable import FeatureAccount

@MainActor
struct FeedbackDraftTests {
    private func filledDraft() -> FeedbackDraft {
        var draft = FeedbackDraft()
        draft.type = "suggestion"
        draft.feature = "score"
        draft.content = "希望成绩页面能够保留搜索内容"
        draft.contactType = "email"
        draft.contact = "student@example.com"
        return draft
    }

    @Test func reopeningRestoresAllFieldsWithoutMixingAccountsOrGuest() {
        let a = AppServices.preview(studentId: "account-a")
        let model = FeedbackFormModel.open(services: a)
        model.draft = filledDraft()
        #expect(FeedbackFormModel.open(services: a).draft == filledDraft())
        let b = AppServices.preview(studentId: "account-b")
        let other = AppServices(backend: b.backend, database: b.database, shared: a.shared, accounts: b.accounts)
        let otherForm = FeedbackFormModel.open(services: other)
        #expect(otherForm.draft == FeedbackDraft())
        otherForm.draft.content = "另一个账号的未完成内容"
        let guest = AppServices.preview(signedIn: false)
        let guestServices = AppServices(backend: guest.backend, database: guest.database, shared: a.shared, accounts: guest.accounts)
        #expect(FeedbackFormModel.open(services: guestServices).draft == FeedbackDraft())
        #expect(FeedbackFormModel.open(services: a).draft == filledDraft())
        #expect(FeedbackFormModel.open(services: other).draft.content == "另一个账号的未完成内容")
    }

    @Test func releasedFormsRestorePersistedFieldsAndSuccessfulClear() async {
        let backend = MockBackendAPI()
        backend.stub("POST /feedback", json: #"{"data":{"id":77}}"#)
        let services = AppServices.preview(backend: backend)
        var form: FeedbackFormModel? = .open(services: services)
        weak var released = form
        form?.draft = filledDraft()
        form = nil
        #expect(released == nil)
        var restored: FeedbackFormModel? = .open(services: services)
        #expect(restored?.draft == filledDraft())
        await restored?.submit()
        weak var submitted = restored
        restored = nil
        #expect(submitted == nil)
        #expect(FeedbackFormModel.open(services: services).draft == FeedbackDraft())
    }

    @Test func failureKeepsDraftAndSuccessClearsPersistedDraft() async {
        let backend = MockBackendAPI()
        let services = AppServices.preview(backend: backend)
        let model = FeedbackFormModel.open(services: services)
        model.draft = filledDraft()
        backend.stub("POST /feedback", error: .network("offline"))
        await model.submit()
        #expect(model.errorMessage != nil && model.submittedID == nil && model.canSubmit)
        #expect(FeedbackFormModel.open(services: services).draft == filledDraft())
        backend.stub("POST /feedback", json: #"{"data":{"id":77}}"#)
        await model.submit()
        #expect(model.submittedID == 77 && model.errorMessage == nil)
        #expect(model.draft == FeedbackDraft())
        #expect(FeedbackFormModel.open(services: services).draft == FeedbackDraft())
    }

    @Test func pendingSubmitPreventsDuplicatesAndIgnoresOldSessionSuccess() async {
        let backend = DelayedFeedbackBackend()
        let base = AppServices.preview()
        let services = AppServices(backend: backend, database: base.database, shared: base.shared, accounts: base.accounts)
        let model = FeedbackFormModel.open(services: services)
        model.draft = filledDraft()
        let submit = Task { await model.submit() }
        while !(await backend.isWaiting) { await Task.yield() }
        #expect(model.isSubmitting && !model.canSubmit)
        await model.submit()
        #expect(await backend.callCount == 1)
        await services.accounts.logout(.jw)
        await backend.finish()
        await submit.value
        #expect(model.submittedID == nil && model.draft == filledDraft() && model.canSubmit)
        #expect(FeedbackFormModel.open(services: services).draft == FeedbackDraft())
    }

    @Test func successDoesNotEraseNewerDraft() async {
        let backend = DelayedFeedbackBackend()
        let base = AppServices.preview()
        let services = AppServices(backend: backend, database: base.database, shared: base.shared, accounts: base.accounts)
        let model = FeedbackFormModel.open(services: services)
        model.draft = filledDraft()
        let submit = Task { await model.submit() }
        while !(await backend.isWaiting) { await Task.yield() }
        let newerForm = FeedbackFormModel.open(services: services)
        newerForm.draft.content = "另一份正在编辑的新反馈内容"
        await backend.finish()
        await submit.value
        #expect(model.submittedID == 77)
        #expect(FeedbackFormModel.open(services: services).draft.content == "另一份正在编辑的新反馈内容")
    }
}

private actor DelayedFeedbackBackend: BackendAPI {
    private var response: CheckedContinuation<Void, Never>?
    private(set) var callCount = 0
    var isWaiting: Bool { response != nil }

    func finish() {
        response?.resume()
        response = nil
    }

    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("unused")
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        callCount += 1
        await withCheckedContinuation { response = $0 }
        return try JSONDecoder().decode(type, from: Data(#"{"data":{"id":77}}"#.utf8))
    }
}
