import GxuAuth
import GxuFoundation
import Observation

@MainActor @Observable
final class FeedbackFormModel {
    var draft = FeedbackDraft()
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?
    var submittedID: Int?

    private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    var canSubmit: Bool { !isSubmitting }

    func submit() async {
        guard !isSubmitting else { return }
        if let message = draft.validationMessage { errorMessage = message; return }
        guard let studentId = services.accounts.studentId else { errorMessage = "请先到设置里登录教务账号"; return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            submittedID = try await FeedbackRepository(backend: services.backend).submit(draft, studentId: studentId)
            draft.content = ""
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            errorMessage = "提交失败：" + error.userMessage
        } catch {
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
    private var page = 1
    private var listRevision = 0

    private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    func reload() async {
        listRevision += 1
        page = 1
        hasMore = true
        await load(reset: true)
    }

    func loadMoreIfNeeded(current item: FeedbackItem) async {
        guard hasMore, !isLoading, item.id == items.last?.id else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        let requestRevision = listRevision
        isLoading = true
        defer { if requestRevision == listRevision { isLoading = false } }
        do {
            let fetched = try await FeedbackRepository(backend: services.backend).publicList(page: page)
            guard requestRevision == listRevision else { return }
            if reset { items = fetched.items } else { items += fetched.items.filter { new in !items.contains { $0.id == new.id } } }
            hasMore = page < fetched.totalPages
            page += 1
            error = nil
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            self.error = error
        } catch {
            self.error = .network("加载失败")
        }
    }
}
