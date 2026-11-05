import ExamKit
import GxuAuth
import GxuDesign
import GxuFoundation
import SwiftUI

public struct ScoreView: View {
    @Environment(\.services) private var services
    private let pendingSource: (any PendingCourseSource)?

    /// `pendingSource` 提供"未出分科目"（已选课程在 FeatureCourse，由 App 注入）；不传则不显示
    public init(pendingSource: (any PendingCourseSource)? = nil) { self.pendingSource = pendingSource }

    public var body: some View {
        Content(services: services, pendingSource: pendingSource)
    }

    private struct Content: View {
        @State private var model: ScoreViewModel
        @State private var expanded: String?

        init(services: AppServices, pendingSource: (any PendingCourseSource)?) {
            _model = State(initialValue: ScoreViewModel(services: services, pendingSource: pendingSource))
        }

        var body: some View {
            List {
                if model.error != nil {
                    errorSection(model.error, hasData: !model.scores.isEmpty, updatedAt: model.lastSyncedAt) {
                        Task { await model.load() }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                if model.scores.isEmpty && model.pending.isEmpty {
                    if model.isLoading {
                        GxuLoadingView("正在查询成绩…").frame(minHeight: 240).listRowBackground(Color.clear)
                    } else if model.error == nil {
                        GxuEmptyView("暂无成绩", systemImage: "list.bullet.clipboard").listRowBackground(Color.clear)
                    }
                } else {
                    if !model.scores.isEmpty {
                    Section {
                        ForEach(model.scores) { score in
                            ScoreRow(score: score, showsTerm: model.query.term == nil, isExpanded: expanded == score.id, usual: model.usual[score.id])
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    expanded = expanded == score.id ? nil : score.id
                                    if expanded != nil { Task { await model.loadUsual(for: score) } }
                                }
                        }
                    } header: {
                        status
                    }
                    }
                    if !model.pending.isEmpty {
                        Section {
                            ForEach(model.pending) { course in
                                HStack {
                                    Text(course.displayName)
                                    Spacer()
                                    Text("未出分").foregroundStyle(.secondary)
                                }
                            }
                        } header: {
                            Text("未出分科目 · \(model.pending.count)门")
                        }
                    }
                }
            }
            .navigationTitle("成绩查询")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if model.isLoading { ProgressView().controlSize(.small) }
                    TermMenu(years: model.years, year: yearBinding, term: termBinding, allowsWholeYear: true)
                    NavigationLink {
                        GpaView(initial: model.query)
                    } label: {
                        Label("绩点计算器", systemImage: "function")
                    }
                }
            }
            .task { await model.resolveInitialTerm() }
            .task(id: LoadKey(value: model.query, ready: model.isReady)) { await model.load() }
            .refreshable { await model.load() }
        }

        private var status: Text {
            let count = "共 \(model.scores.count) 门"
            guard let date = model.lastSyncedAt else { return Text(count) }
            return Text("\(count) · 上次同步 \(syncText(date))")
        }

        private var yearBinding: Binding<Int> {
            Binding(get: { model.query.year }, set: { model.query.year = $0 })
        }

        private var termBinding: Binding<Int?> {
            Binding(get: { model.query.term }, set: { model.query.term = $0 })
        }
    }
}

private struct ScoreRow: View {
    let score: Score
    let showsTerm: Bool
    let isExpanded: Bool
    let usual: UsualScoreState?

    private var failed: Bool { (score.score ?? 100) < 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if showsTerm {
                    Text(termLabel).font(.footnote).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
                }
                Text(score.courseName).font(.headline)
                Spacer()
                Text(score.score.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "—")
                    .font(.title3.bold())
                    .foregroundStyle(failed ? Color.red : Color.primary)
            }

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

    private var termLabel: String {
        score.term == 1 ? "\(score.year) 秋" : score.term == 2 ? "\(score.year + 1) 春" : "\(score.year) 其他"
    }

    @ViewBuilder
    private var usualRows: some View {
        switch usual {
        case .loading:
            detail("平时成绩", "正在加载中……")
        case .failed(let message):
            Text(message).foregroundStyle(.red)
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
