import ExamKit
import GxuAuth
import GxuDesign
import GxuFoundation
import SwiftUI

public struct ScoreView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View {
        Content(services: services)
    }

    private struct Content: View {
        @State private var model: ScoreViewModel
        @State private var expanded: String?

        init(services: AppServices) {
            _model = State(initialValue: ScoreViewModel(services: services))
        }

        var body: some View {
            List {
                Section {
                    TermPicker(years: model.years, year: yearBinding, term: termBinding, allowsWholeYear: true)
                    status
                }
                if model.error != nil {
                    errorSection(model.error, hasData: !model.scores.isEmpty, updatedAt: model.lastSyncedAt) {
                        Task { await model.load() }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                if model.scores.isEmpty {
                    if model.isLoading {
                        GxuLoadingView("正在查询成绩…").frame(minHeight: 240).listRowBackground(Color.clear)
                    } else if model.error == nil {
                        GxuEmptyView("暂无成绩", systemImage: "list.bullet.clipboard").listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(model.scores) { score in
                            ScoreRow(score: score, isExpanded: expanded == score.id, usual: model.usual[score.id])
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    expanded = expanded == score.id ? nil : score.id
                                    if expanded != nil { Task { await model.loadUsual(for: score) } }
                                }
                        }
                    } header: {
                        Text("共 \(model.scores.count) 门")
                    }
                }
            }
            .navigationTitle("成绩查询")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                NavigationLink {
                    GpaView(initial: model.query)
                } label: {
                    Label("绩点计算器", systemImage: "function")
                }
            }
            .task { await model.resolveInitialTerm() }
            .task(id: LoadKey(value: model.query, ready: model.isReady)) { await model.load() }
            .refreshable { await model.load() }
        }

        @ViewBuilder
        private var status: some View {
            HStack {
                if let date = model.lastSyncedAt {
                    Text("上次同步: \(syncText(date))").font(.footnote).foregroundStyle(.secondary)
                }
                if model.isLoading { ProgressView().controlSize(.small) }
            }
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
    let isExpanded: Bool
    let usual: UsualScoreState?

    private var failed: Bool { (score.score ?? 100) < 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(termLabel).font(.footnote).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
                Text(score.courseName).font(.headline)
                Spacer()
                Text(score.score.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "—")
                    .font(.title3.bold())
            }
            .foregroundStyle(failed ? Color.red : Color.primary)

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
                    (item.name.isEmpty ? "暂无" : item.name) + (item.hasRatio ? "（\(item.ratio) %）" : ""),
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
