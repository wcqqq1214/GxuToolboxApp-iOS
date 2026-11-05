import GxuAuth
import GxuDesign
import GxuFoundation
import Observation
import SwiftUI

/// 教师查询：搜索（姓名 / 单位 / 职称 / 一级学科）、分页加载更多、详情；没搜索时显示学校领导。
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

    func reset() { version += 1; keyword = ""; active = ""; results = []; total = 0; page = 1; pages = 0; searchError = nil; moreError = nil; isSearching = false }
}

public struct TeacherSearchView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View { Content(services: services) }

    private struct Content: View {
        @State private var model: TeacherSearchModel

        init(services: AppServices) { _model = State(initialValue: TeacherSearchModel(services: services)) }

        var body: some View {
            List {
                if !model.isActive && !model.isSearching {
                    ForEach(SchoolLeaders.all) { group in
                        Section(group.title) { ForEach(group.leaders) { LeaderRow(leader: $0) } }
                    }
                } else if model.isSearching {
                    GxuLoadingView("正在查询教师信息…").frame(minHeight: 240).listRowBackground(Color.clear)
                } else if let error = model.searchError {
                    GxuErrorView(error) { Task { await model.search() } }.listRowBackground(Color.clear)
                } else if model.results.isEmpty {
                    GxuEmptyView("暂无匹配教师", systemImage: "person.text.rectangle").listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(model.results) { teacher in
                            NavigationLink { TeacherDetailView(teacher: teacher) } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(teacher.name).font(.headline)
                                    Text(teacher.unit).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if model.hasMore || model.moreError != nil {
                            footer
                        }
                    } header: {
                        Text("共有 \(model.total) 个结果")
                    }
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

private struct LeaderRow: View {
    let leader: SchoolLeader

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: leader.photoURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.square").font(.largeTitle).foregroundStyle(.secondary)
            }
            .frame(width: 52, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(leader.name).font(.headline)
                Text(leader.position).font(.subheadline).foregroundStyle(.secondary)
                ForEach(leader.duties, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

@MainActor @Observable
final class TeacherDetailModel {
    private(set) var detail: TeacherDetail?
    private(set) var isLoading = true
    private(set) var error: String?
    private let api: TeacherAPI
    private let teacher: TeacherSummary

    init(services: AppServices, teacher: TeacherSummary) {
        api = TeacherAPI(backend: services.backend)
        self.teacher = teacher
    }

    func load() async {
        isLoading = true; error = nil; detail = nil
        defer { isLoading = false }
        do {
            guard let d = try await api.profile(name: teacher.name, unit: teacher.unit) else { error = "暂无教师信息"; return }
            detail = d
        } catch is CancellationError {
        } catch {
            self.error = ((error as? GxuError) ?? .network(error.localizedDescription)).userMessage
        }
    }
}

public struct TeacherDetailView: View {
    @Environment(\.services) private var services
    let teacher: TeacherSummary

    public init(teacher: TeacherSummary) { self.teacher = teacher }

    public var body: some View { Content(services: services, teacher: teacher) }

    private struct Content: View {
        @State private var model: TeacherDetailModel
        let teacher: TeacherSummary

        init(services: AppServices, teacher: TeacherSummary) {
            self.teacher = teacher
            _model = State(initialValue: TeacherDetailModel(services: services, teacher: teacher))
        }

        var body: some View {
            List {
                if model.isLoading {
                    GxuLoadingView("正在加载…").frame(minHeight: 240).listRowBackground(Color.clear)
                } else if let error = model.error {
                    GxuErrorView(error) { Task { await model.load() } }.listRowBackground(Color.clear)
                } else if let detail = model.detail {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(detail.base.name.isEmpty ? teacher.name : detail.base.name).font(.title2.bold())
                            Text([teacher.unit, detail.base.title, detail.base.position].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(TeacherSections.build(detail)) { section in
                        Section(section.title) { Text(section.text).textSelection(.enabled) }
                    }
                }
            }
            .navigationTitle("教师信息")
            .navigationBarTitleDisplayMode(.inline)
            .gxuHidesTabChrome()
            .task { await model.load() }
        }
    }
}
