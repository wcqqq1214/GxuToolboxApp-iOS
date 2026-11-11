import GxuAuth
import GxuDesign
import SwiftUI

public struct LegacyElectiveStrategyView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View { Content(services: services) }

    private struct Content: View {
        @State private var model: ElectiveStrategyViewModel

        init(services: AppServices) {
            _model = State(initialValue: ElectiveStrategyViewModel(services: services))
        }

        var body: some View {
            let hasData = !model.courses.isEmpty || !model.passedScores.isEmpty
            List {
                if let error = model.error, !hasData {
                    GxuErrorView(error.userMessage) { Task { await model.load() } }.listRowBackground(Color.clear)
                } else if model.isLoading && !hasData {
                    GxuLoadingView("正在整理已选课程和成绩…").frame(minHeight: 240).listRowBackground(Color.clear)
                } else {
                    content
                }
            }
            .navigationTitle("选课策略")
            .navigationBarTitleDisplayMode(.inline)
            .gxuHidesTabChrome()
            .task { await model.load() }
            .refreshable { await model.load() }
        }

        @ViewBuilder
        private var content: some View {
            let strategy = model.strategy
            let stats = model.stats
            Section {
                ForEach(strategy.rows(stats)) { row in
                    HStack {
                        Text(row.label)
                        Spacer()
                        Text(row.value).bold().foregroundStyle(row.passed ? Color.green : Color.red)
                    }
                }
            } header: {
                Text(strategy.name)
            }
            Section("待完成必修课") {
                if stats.remainingRequired.isEmpty {
                    Label("全部完成", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    ForEach(stats.remainingRequired, id: \.self) { Text($0).foregroundStyle(.red) }
                }
            }
            Section {
                HStack {
                    Text("毕业资格").font(.headline)
                    Spacer()
                    Text(stats.isQualified ? "达标" : "不达标").font(.headline).foregroundStyle(stats.isQualified ? Color.green : Color.red)
                }
            }
            Section {
                if model.courses.isEmpty {
                    Text("没有已选的通识选修课").foregroundStyle(.secondary)
                }
                ForEach(model.courses) { course in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                if course.isOnline { Image(systemName: "wifi").font(.caption).foregroundStyle(.tint) }
                                Text(course.courseName)
                            }
                            Text("\(course.system) · 学分 \(ElectiveStrategy.number(course.credit))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let score = model.passedScores[course.courseName] {
                            Text("\(score.formatted(.number.precision(.fractionLength(0...1))))分").bold().foregroundStyle(.green)
                        } else {
                            Text("已挂科或未出成绩").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("课程成绩")
            } footer: {
                Text("网课用 Wi-Fi 图标标记。只有已选且成绩及格的通识选修课才计入上面的统计。")
            }
        }
    }
}
