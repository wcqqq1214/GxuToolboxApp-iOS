import GxuAuth
import GxuDesign
import GxuFoundation
import Observation
import SwiftUI

@MainActor @Observable
final class TeacherSearchModel {
    var draftQuery = ""
    private(set) var submittedQuery = ""
    private(set) var results: [TeacherSummary] = []
    private(set) var total = 0
    private(set) var page = 1
    private(set) var pages = 0
    private(set) var isSearching = false
    private(set) var isLoadingMore = false
    private(set) var searchError: String?
    private(set) var moreError: String?
    private var searchRevision = 0
    private let api: TeacherAPI

    init(services: AppServices) {
        api = TeacherAPI(backend: services.backend)
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-GxuTeacherKeyword"), i + 1 < args.count { draftQuery = args[i + 1] }
        #endif
    }

    var hasMore: Bool { page < pages }
    var hasSubmittedQuery: Bool { !submittedQuery.isEmpty }

    func search() async {
        let query = draftQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchRevision += 1
        let requestRevision = searchRevision
        submittedQuery = query
        results = []
        total = 0
        page = 1
        pages = 0
        searchError = nil
        moreError = nil
        isLoadingMore = false
        isSearching = true
        defer { if searchRevision == requestRevision { isSearching = false } }
        do {
            let first = try await api.search(query)
            guard searchRevision == requestRevision else { return }
            results = first.list; pages = first.pages; total = first.total
        } catch is CancellationError {
        } catch {
            guard searchRevision == requestRevision else { return }
            searchError = ((error as? GxuError) ?? .network(error.localizedDescription)).userMessage
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, !isSearching, moreError == nil else { return }
        searchRevision += 1
        let requestRevision = searchRevision
        isLoadingMore = true
        defer { if searchRevision == requestRevision { isLoadingMore = false } }
        do {
            let next = try await api.search(submittedQuery, page: page + 1)
            guard searchRevision == requestRevision else { return }
            results += next.list; page += 1; pages = next.pages; total = next.total
        } catch is CancellationError {
        } catch {
            guard searchRevision == requestRevision else { return }
            moreError = ((error as? GxuError) ?? .network(error.localizedDescription)).userMessage
        }
    }

    func retryMore() async { moreError = nil; await loadMore() }

    func reset() {
        searchRevision += 1
        isLoadingMore = false
        draftQuery = ""
        submittedQuery = ""
        results = []
        total = 0
        page = 1
        pages = 0
        searchError = nil
        moreError = nil
        isSearching = false
    }
}

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
                if !model.hasSubmittedQuery && !model.isSearching {
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
            .searchable(text: $model.draftQuery, prompt: "姓名 / 单位 / 职称 / 一级学科")
            .onSubmit(of: .search) { Task { await model.search() } }
            #if DEBUG
            .task { if !model.draftQuery.isEmpty { await model.search() } }
            #endif
            .onChange(of: model.draftQuery) { _, query in
                if query.isEmpty && model.hasSubmittedQuery { model.reset() }
            }
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
