import GxuAuth
import GxuDesign
import GxuFoundation
import Observation
import SwiftUI

/// 教师查询：搜索（姓名 / 单位 / 职称 / 一级学科）、分页加载更多、详情；没搜索时显示搜索引导。
@MainActor @Observable
final class TeacherSearchModel {
    var keyword = ""
    private(set) var active = ""
    private(set) var results: [TeacherSummary] = []
    private(set) var total = 0
    private(set) var page = 1
    private(set) var pages = 0
    private(set) var isSearching = false
    private(set) var isLoadingMore = false
    private(set) var searchError: String?
    private(set) var moreError: String?
    private var version = 0
    private let api: TeacherAPI

    init(services: AppServices) {
        api = TeacherAPI(backend: services.backend)
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-GxuTeacherKeyword"), i + 1 < args.count { keyword = args[i + 1] }
        #endif
    }

    var hasMore: Bool { page < pages }
    var isActive: Bool { !active.isEmpty }

    func search() async {
        let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        version += 1
        let mine = version
        active = key; results = []; total = 0; page = 1; pages = 0; searchError = nil; moreError = nil
        isLoadingMore = false   // 正在翻页的请求已被这次搜索作废，它的 defer 不会再清这个标志
        isSearching = true
        defer { if version == mine { isSearching = false } }
        do {
            let first = try await api.search(key)
            guard version == mine else { return }
            results = first.list; pages = first.pages; total = first.total
        } catch is CancellationError {
        } catch {
            guard version == mine else { return }
            searchError = ((error as? GxuError) ?? .network(error.localizedDescription)).userMessage
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, !isSearching, moreError == nil else { return }
        version += 1
        let mine = version
        isLoadingMore = true
        defer { if version == mine { isLoadingMore = false } }
        do {
            let next = try await api.search(active, page: page + 1)
            guard version == mine else { return }
            results += next.list; page += 1; pages = next.pages; total = next.total
        } catch is CancellationError {
        } catch {
            guard version == mine else { return }
            moreError = ((error as? GxuError) ?? .network(error.localizedDescription)).userMessage
        }
    }

    func retryMore() async { moreError = nil; await loadMore() }

    func reset() { version += 1; isLoadingMore = false; keyword = ""; active = ""; results = []; total = 0; page = 1; pages = 0; searchError = nil; moreError = nil; isSearching = false }
}

/// 头像：有地址就加载，加载中 / 失败 / 没有地址时用姓名的第一个字占位，不留空白
struct TeacherAvatar: View {
    let url: URL?
    let name: String
    var size: CGSize = CGSize(width: 56, height: 56)
    var cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            Color.accentColor.opacity(0.15)
            Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)))
                .font(.system(size: size.width * 0.42, weight: .semibold)).foregroundStyle(Color.accentColor)
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

public struct TeacherSearchView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View { Content(services: services) }

    private struct Content: View {
        @State private var model: TeacherSearchModel

        init(services: AppServices) { _model = State(initialValue: TeacherSearchModel(services: services)) }

        var body: some View {
            Group {
                if !model.isActive && !model.isSearching {
                    GxuEmptyView("搜索教师信息", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                } else {
                    results
                }
            }
            .navigationTitle("教师查询")
            .navigationBarTitleDisplayMode(.inline)
            .gxuHidesTabChrome()
            .searchable(text: $model.keyword, prompt: "姓名 / 单位 / 职称 / 一级学科")
            .onSubmit(of: .search) { Task { await model.search() } }
            #if DEBUG
            .task { if !model.keyword.isEmpty { await model.search() } }
            #endif
            .onChange(of: model.keyword) { _, new in if new.isEmpty && model.isActive { model.reset() } }
        }

        private var results: some View {
            List {
                if model.isSearching {
                    GxuLoadingView("正在查询教师信息…").frame(minHeight: 240).listRowBackground(Color.clear)
                } else if let error = model.searchError {
                    GxuErrorView(error) { Task { await model.search() } }.listRowBackground(Color.clear)
                } else if model.results.isEmpty {
                    GxuEmptyView("暂无匹配教师", systemImage: "person.text.rectangle").listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(model.results) { teacher in
                            NavigationLink { TeacherDetailView(teacher: teacher) } label: {
                                TeacherRow(teacher: teacher)
                            }
                        }
                        if model.hasMore || model.moreError != nil { footer }
                    } header: {
                        Text("共有 \(model.total) 个结果")
                    }
                }
            }
        }

        @ViewBuilder
        private var footer: some View {
            if let error = model.moreError {
                Button("\(error) 点按重试") { Task { await model.retryMore() } }.foregroundStyle(.red)
            } else {
                ProgressView().frame(maxWidth: .infinity).task { await model.loadMore() }
            }
        }
    }
}

public struct TeacherDetailView: View {
    @Environment(\.services) private var services
    let teacher: TeacherSummary
    let leader: SchoolLeader?

    public init(teacher: TeacherSummary) { self.teacher = teacher; leader = nil }
    init(teacher: TeacherSummary, leader: SchoolLeader?) { self.teacher = teacher; self.leader = leader }

    public var body: some View { Content(services: services, teacher: teacher, leader: leader) }

    private struct Content: View {
        @State private var model: TeacherDetailModel
        let teacher: TeacherSummary

        init(services: AppServices, teacher: TeacherSummary, leader: SchoolLeader?) {
            self.teacher = teacher
            _model = State(initialValue: TeacherDetailModel(services: services, teacher: teacher, leader: leader))
        }

        var body: some View {
            List {
                if model.isLoading {
                    GxuLoadingView("正在加载…").frame(minHeight: 240).listRowBackground(Color.clear)
                } else if let error = model.error {
                    GxuErrorView(error) { Task { await model.load() } }.listRowBackground(Color.clear)
                } else {
                    header
                    if let leader = model.leader {
                        let duties = ([leader.position].filter { !$0.isEmpty } + leader.duties).joined(separator: "\n")
                        if !duties.isEmpty { Section("职务与分工") { Text(duties) } }
                    }
                    if let detail = model.detail {
                        ForEach(TeacherSections.build(detail)) { section in
                            TeacherSectionView(section: section)
                        }
                    }
                }
            }
            .navigationTitle("教师信息")
            .navigationBarTitleDisplayMode(.inline)
            .gxuHidesTabChrome()
            .task { await model.load() }
        }

        private var header: some View {
            let detail = model.detail
            let info = detail.map { TeacherHeader.make($0, fallbackName: teacher.name) }
            let photo = detail.flatMap { TeacherAvatarURL.url($0.base.pic) } ?? teacher.avatarURL
            return Section {
                TeacherHeaderCard(info: info, name: info?.name ?? teacher.name, unit: teacher.unit, photo: photo)
            }
        }
    }
}

@MainActor @Observable
final class TeacherDetailModel {
    private(set) var detail: TeacherDetail?
    private(set) var isLoading = true
    private(set) var error: String?
    private let api: TeacherAPI
    private let teacher: TeacherSummary
    /// 学校领导：教师库里的资料很少（常常只有姓名和职称），查不到时界面仍用领导自己的信息，不当成错误
    let leader: SchoolLeader?

    init(services: AppServices, teacher: TeacherSummary, leader: SchoolLeader? = nil) {
        api = TeacherAPI(backend: services.backend)
        self.teacher = teacher
        self.leader = leader
    }

    func load() async {
        isLoading = true; error = nil; detail = nil
        defer { isLoading = false }
        do {
            guard let d = try await api.profile(name: teacher.name, unit: teacher.unit) else {
                if leader == nil { error = "暂无教师信息" }
                return
            }
            detail = d
        } catch is CancellationError {
        } catch {
            if leader == nil { self.error = ((error as? GxuError) ?? .network(error.localizedDescription)).userMessage }
        }
    }
}
