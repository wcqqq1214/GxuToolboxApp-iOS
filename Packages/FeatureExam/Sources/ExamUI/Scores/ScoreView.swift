import ExamKit
import GxuAuth
import GxuDesign
import GxuFoundation
import SwiftUI

public struct ScoreView: View {
    @Environment(\.services) private var services
    private let pendingSource: (any PendingCourseSource)?

    public init(pendingSource: (any PendingCourseSource)? = nil) { self.pendingSource = pendingSource }

    public var body: some View {
        Content(services: services, pendingSource: pendingSource)
    }

    private struct Content: View {
        @State private var model: ScoreViewModel
        @State private var expanded: String?
        @State private var searchText = ""

        init(services: AppServices, pendingSource: (any PendingCourseSource)?) {
            _model = State(initialValue: ScoreViewModel(services: services, pendingSource: pendingSource))
        }

        var body: some View {
            List {
                Section {
                    TermMenu(years: model.years, year: yearBinding, term: termBinding, allowsWholeYear: true,
                             isAll: Binding(get: { model.query.isAll }, set: { model.query.isAll = $0 }))
                } footer: {
                    if !model.scores.isEmpty { status }
                }
                if model.error != nil {
                    errorSection(model.error, hasData: !model.scores.isEmpty, updatedAt: model.lastSyncedAt) {
                        Task { await model.load() }
                    }
                    
                    .listRowBackground(Color.clear)
                }
                if model.scores.isEmpty && model.pending.isEmpty {
                    if model.isLoading {
                        GxuLoadingView("正在查询成绩…").frame(minHeight: 240).listRowBackground(Color.clear)
                    } else if model.error == nil {
                        GxuEmptyView("暂无成绩", systemImage: "list.bullet.clipboard").listRowBackground(Color.clear)
                    }
                } else if visibleScores.isEmpty && visiblePending.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                } else {
                    if !visibleScores.isEmpty {
                        if model.query.isAll || model.query.term == nil {
                            ForEach(ScoreGroup.group(visibleScores)) { group in
                                Section(ScoreHistory.title(for: group)) {
                                    ForEach(group.scores) { score in row(score) }
                                }
                            }
                        } else {
                            Section {
                                ForEach(visibleScores) { score in row(score) }
                            }
                        }
                    }
                    if !visiblePending.isEmpty {
                        Section {
                            ForEach(visiblePending) { course in
                                Text(course.displayName)
                                    .accessibilityValue("未出分")
                            }
                        } header: {
                            Text("未出分科目")
                        }
                    }
                }
            }
            .navigationTitle("成绩查询")
            .navigationBarTitleDisplayMode(.inline)
            .gxuHidesTabChrome()
            .searchable(text: $searchText, prompt: "搜索课程或教师")
            .onChange(of: model.query) { expanded = nil }
            .toolbar {
                NavigationLink {
                    GpaView()
                } label: {
                    Label("绩点计算器", systemImage: "function")
                }
            }
            .task { await model.resolveInitialTerm() }
            .task(id: LoadKey(value: model.query, ready: model.isQueryReady)) { await model.load() }
            .refreshable { await model.load() }
        }

        private var visibleScores: [Score] { ScoreHistory.matching(model.scores, query: searchText) }

        private var visiblePending: [PendingCourse] {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return model.pending.filter { query.isEmpty || $0.displayName.localizedStandardContains(query) }
        }

        private func row(_ score: Score) -> some View {
            ScoreRow(score: score, isExpanded: expanded == score.id, usual: model.usual[score.id],
                     onToggle: {
                         expanded = expanded == score.id ? nil : score.id
                         if expanded != nil { Task { await model.loadUsual(for: score) } }
                     },
                     onRetry: { Task { await model.loadUsual(for: score) } })
        }

        private var status: Text {
            let count = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "共 \(model.scores.count) 条成绩" : "找到 \(visibleScores.count) 条成绩，共 \(model.scores.count) 条"
            guard let date = model.lastSyncedAt else { return Text(count) }
            let sync = Text("上次同步 \(syncText(date))")
                .textScale(.secondary)
                .foregroundStyle(Color.secondary.opacity(0.9))
            return Text("\(count) · \(sync)")
        }

        private var yearBinding: Binding<Int> {
            Binding(get: { model.query.year }, set: { model.query.year = $0; model.query.isAll = false })
        }

        private var termBinding: Binding<Int?> {
            Binding(get: { model.query.term }, set: { model.query.term = $0; model.query.isAll = false })
        }
    }
}

private struct ScoreRow: View {
    let score: Score
    let isExpanded: Bool
    let usual: UsualScoreState?
    let onToggle: () -> Void
    let onRetry: () -> Void

    private var failed: Bool { (score.score ?? 100) < 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(score.courseName).font(.headline)
                Spacer()
                Text(score.score.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "—")
                    .font(.title3.bold())
                    .foregroundStyle(failed ? Color.red : Color.primary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)
            .accessibilityAction { onToggle() }

            if isExpanded {
                VStack(spacing: 6) {
                    usualRows
                    detail("发布时间", score.uploadAt)
                    detail("学分", score.credit.map { $0.formatted() } ?? "暂无")
                    detail("绩点", GpaCalculator.pointText(for: score.score))
                    detail("教师", score.teacherName.isEmpty ? "暂无" : score.teacherName)
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var usualRows: some View {
        switch usual {
        case .loading:
            detail("平时成绩", "正在加载中……")
        case .failed(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text(message).foregroundStyle(.red)
                Button("重试", action: onRetry)
                    .buttonStyle(.borderless)
                    .accessibilityLabel("重试加载平时成绩")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .loaded(let items) where items.isEmpty:
            Text("暂无平时成绩")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .loaded(let items):
            ForEach(items, id: \.self) { item in
                detail(
                    (item.name.isEmpty ? "暂无" : item.name) + (item.hasRatio ? "（\(item.ratio)%）" : ""),
                    item.score.isEmpty ? "暂无" : item.score
                )
            }
        case nil:
            EmptyView()
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
