import Foundation
import GxuAuth
import GxuFoundation
import Observation

@MainActor @Observable
final class OAFilesModel {
    private(set) var rows: [OAFileRow] = []
    private(set) var isLoading = false
    private(set) var error: GxuError?
    private(set) var hasMore = false
    var typeId = 0
    /// 已提交的搜索词（提交搜索后才请求，避免每敲一个字就请求）
    var keyword = ""

    private var page = 1
    /// 每次 reload 加一：慢的旧请求回来时发现代数变了就丢弃，避免覆盖新筛选 / 新搜索的结果，也避免页码被旧请求推进
    private var generation = 0
    private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    private(set) var isDemo = false
    var hasAccount: Bool { isDemo || services.accounts.states[.oa] != .noAccount }

    /// DEBUG 截图用：不联网，直接显示示例数据
    static func demo(services: AppServices) -> OAFilesModel {
        let model = OAFilesModel(services: services)
        model.isDemo = true
        model.rows = [
            OAFileRow(id: 1, title: "关于做好 2026 年秋季学期期末考试工作的通知", fileNum: "西大教〔2026〕31号", typeName: "行政文件", department: "教务处", date: "2026-11-03", isUrgent: true, isRead: false),
            OAFileRow(id: 2, title: "关于召开学校第十二次党代会的通知", fileNum: "西大党〔2026〕27号", typeName: "党委文件", department: "党委办公室", date: "2026-11-02", isUrgent: false, isRead: false),
            OAFileRow(id: 3, title: "2026 年度大学生创新创业训练计划项目申报通知", fileNum: "西大教〔2026〕29号", typeName: "行政文件", department: "教务处", date: "2026-10-28", isUrgent: false, isRead: true),
        ]
        return model
    }

    func reload() async {
        guard hasAccount, let oa = services.accounts.oa else { error = .notLoggedIn(.oa); return }
        generation += 1
        page = 1
        await load(OAFilesAPI(session: oa), reset: true)
    }

    func loadMoreIfNeeded(current row: OAFileRow) async {
        guard hasMore, !isLoading, row.id == rows.last?.id, let oa = services.accounts.oa else { return }
        await load(OAFilesAPI(session: oa), reset: false)
    }

    private func load(_ api: OAFilesAPI, reset: Bool) async {
        let mine = generation
        isLoading = true
        defer { if mine == generation { isLoading = false } }
        do {
            let result = try await api.list(page: page, typeId: typeId, keyword: keyword)
            guard mine == generation else { return }   // 已经有更新的 reload，这个结果作废
            rows = reset ? result.rows : rows + result.rows.filter { new in !rows.contains { $0.id == new.id } }
            hasMore = result.hasNext
            page += 1
            error = nil
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            guard mine == generation else { return }
            if reset { rows = [] }
            self.error = error
        } catch {
            guard mine == generation else { return }
            self.error = .network("加载失败")
        }
    }
}

@MainActor @Observable
final class OAFileDetailModel {
    private(set) var detail: OAFileDetail?
    private(set) var isLoading = true
    private(set) var error: GxuError?
    private(set) var isPreparingPreview = false
    var previewURL: URL?
    private(set) var previewError: String?

    /// DEBUG 截图用：不联网，直接显示示例详情
    static func demo(row: OAFileRow, services: AppServices) -> OAFileDetailModel {
        let model = OAFileDetailModel(row: row, services: services)
        model.detail = OAFileDetail(
            id: row.id, title: row.title, fileNum: row.fileNum, typeName: row.typeName, department: row.department, date: row.date,
            html: "<p>各学院（部）：</p><p>为做好本学期期末考试工作，现将有关事项通知如下……</p><table border=\"1\" cellpadding=\"6\"><tr><td>考试时间</td><td>2027 年 1 月 11 日—1 月 22 日</td></tr></table>",
            pdfURL: URL(string: "https://oa.gxu.edu.cn/f/1.pdf"), docxURL: nil
        )
        model.isLoading = false
        return model
    }

    let row: OAFileRow
    private let services: AppServices

    init(row: OAFileRow, services: AppServices) {
        self.row = row
        self.services = services
    }

    func load() async {
        guard let oa = services.accounts.oa else { error = .notLoggedIn(.oa); isLoading = false; return }
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await OAFilesAPI(session: oa).detail(id: row.id)
            error = nil
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            self.error = error
        } catch {
            self.error = .network("加载失败")
        }
    }

    /// 下载 PDF / DOCX 到临时目录并交给 QuickLook
    func preview(_ url: URL, preferredExtension: String?) async {
        guard let oa = services.accounts.oa, !isPreparingPreview else { return }
        isPreparingPreview = true
        previewError = nil
        defer { isPreparingPreview = false }
        do {
            previewURL = try await OAFilesAPI(session: oa).localFile(for: url, preferredExtension: preferredExtension)
        } catch is CancellationError {
            return
        } catch let error as GxuError {
            previewError = error.userMessage
        } catch {
            previewError = "文件下载失败"
        }
    }
}

@MainActor @Observable
final class WjxtPendingModel {
    private(set) var files: [WjxtPendingFile] = []
    private(set) var isLoading = false
    private(set) var error: GxuError?
    private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    var cookies: [HTTPCookie] { services.accounts.wjxt?.sessionCookies() ?? [] }

    func load() async {
        guard let wjxt = services.accounts.wjxt else { error = .notLoggedIn(.oa); return }
        isLoading = true
        defer { isLoading = false }
        do {
            files = try await wjxt.pendingFiles()
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
