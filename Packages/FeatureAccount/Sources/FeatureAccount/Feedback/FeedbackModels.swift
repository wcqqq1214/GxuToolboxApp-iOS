import Foundation
import GxuAuth
import GxuFoundation
import Observation
import GxuStorage

@MainActor @Observable
final class FeedbackFormModel {
    private struct OpenForm {
        weak var model: FeedbackFormModel?
    }

    private static var openForms: [UUID: OpenForm] = [:]

    static func open(services: AppServices) -> FeedbackFormModel {
        openForms = openForms.filter { $0.value.model != nil }
        let session = services.accounts.jwSessionID
        if let model = openForms[session]?.model { return model }
        let model = FeedbackFormModel(services: services)
        openForms[session] = OpenForm(model: model)
        return model
    }

    var draft: FeedbackDraft {
        didSet { services.shared.set(draft == FeedbackDraft() ? nil : draft, for: draftKey) }
    }
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
    var submittedID: Int?

    private let services: AppServices
    private let studentId: String?
    private let draftKey: SharedKey<FeedbackDraft>

    private init(services: AppServices) {
        self.services = services
        studentId = services.accounts.studentId
        let key = SharedKey<FeedbackDraft>("feedback.draft.v1." + (studentId.map { "account." + $0 } ?? "guest"))
        draftKey = key
        draft = services.shared.value(key) ?? FeedbackDraft()
    }

    var canSubmit: Bool { !isSubmitting }

    func submit() async {
        guard !isSubmitting else { return }
        guard let studentId, studentId == services.accounts.studentId else { errorMessage = "请先到设置里登录教务账号"; return }
        if let message = draft.validationMessage { errorMessage = message; return }
        let session = services.accounts.jwSessionID
        let submittedDraft = draft
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let id = try await FeedbackRepository(backend: services.backend).submit(submittedDraft, studentId: studentId)
            guard services.accounts.jwSessionID == session, !Task.isCancelled else { return }
            submittedID = id
            if draft == submittedDraft, services.shared.value(draftKey) == submittedDraft {
                draft = FeedbackDraft()
            }
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            guard services.accounts.jwSessionID == session else { return }
            errorMessage = "提交失败：" + error.userMessage
        } catch {
            guard services.accounts.jwSessionID == session else { return }
            errorMessage = "提交失败，请稍后重试"
        }
    }
}

@MainActor @Observable
final class FeedbackListModel {
    private(set) var items: [FeedbackItem] = []
    private(set) var isLoading = false
    private(set) var error: GxuError?
    private(set) var hasMore = true
    let mine: Bool
    private var loadedStudentId: String?
    var accountID: String? { mine ? services.accounts.studentId : nil }
    var needsLogin: Bool { mine && accountID == nil }
    private var page = 1
    private var listRevision = 0

    private let services: AppServices

    init(services: AppServices, mine: Bool = false) {
        self.mine = mine
        self.services = services
    }

    func reload() async {
        listRevision += 1
        if loadedStudentId != accountID { items = [] }
        loadedStudentId = accountID
        error = nil
        page = 1
        hasMore = true
        if needsLogin {
            items = []
            hasMore = false
            isLoading = false
            return
        }
        await load(reset: true)
    }

    func loadMoreIfNeeded(current item: FeedbackItem) async {
        guard hasMore, !isLoading, item.id == items.last?.id else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        guard !needsLogin else { return }
        let studentId = accountID
        let requestRevision = listRevision
        isLoading = true
        defer { if requestRevision == listRevision { isLoading = false } }
        do {
            let repository = FeedbackRepository(backend: services.backend)
            let fetched: FeedbackPage
            if mine, let studentId {
                fetched = try await repository.myList(studentId: studentId, page: page)
            } else {
                fetched = try await repository.publicList(page: page)
            }
            guard requestRevision == listRevision, studentId == accountID else { return }
            if reset { items = fetched.items } else { items += fetched.items.filter { new in !items.contains { $0.id == new.id } } }
            hasMore = page < fetched.totalPages
            page += 1
            error = nil
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            guard requestRevision == listRevision, studentId == accountID else { return }
            self.error = error
        } catch {
            guard requestRevision == listRevision, studentId == accountID else { return }
            self.error = .network("加载失败")
        }
    }
}
