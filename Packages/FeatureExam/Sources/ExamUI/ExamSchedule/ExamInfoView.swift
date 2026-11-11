import ExamKit
import GxuAuth
import GxuDesign
import GxuFoundation
import SwiftUI

public struct ExamInfoView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View {
        Content(services: services)
    }

    private struct Content: View {
        @State private var model: ExamInfoViewModel

        init(services: AppServices) {
            _model = State(initialValue: ExamInfoViewModel(services: services))
        }

        var body: some View {
            List {
                Section { TermMenu(years: model.years, year: yearBinding, term: termBinding) }
                if model.error != nil {
                    errorSection(model.error, hasData: model.hasData) { Task { await model.load() } }
                        
                        .listRowBackground(Color.clear)
                }
                if model.hasData {
                    section("即将开考", model.sections.notPast)
                    section("已结束", model.sections.past)
                } else if model.isLoading {
                    GxuLoadingView("正在查询考试安排…")
                        .frame(minHeight: 240).listRowBackground(Color.clear)
                } else if model.error == nil {
                    GxuEmptyView("本学期暂无考试安排", systemImage: "calendar")
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("考试信息")
            .navigationBarTitleDisplayMode(.inline)
            .gxuHidesTabChrome()
            .task { await model.resolveInitialTerm() }
            .task(id: LoadKey(value: model.term, ready: model.hasResolvedInitialTerm)) { await model.load() }
            .refreshable { await model.load() }
        }

        private var yearBinding: Binding<Int> {
            Binding(get: { model.term.year }, set: { model.term = AcademicTerm(year: $0, term: model.term.term) })
        }

        private var termBinding: Binding<Int?> {
            Binding(get: { model.term.term }, set: { model.term = AcademicTerm(year: model.term.year, term: $0 ?? 1) })
        }

        @ViewBuilder
        private func section(_ title: String, _ items: [ExamItem]) -> some View {
            if !items.isEmpty {
                Section {
                    ForEach(items) { ExamRow(item: $0) }
                } header: {
                    Text(title)
                }
            }
        }
    }
}

private struct ExamRow: View {
    let item: ExamItem

    private var detail: String {
        [item.exam.classroom, item.status == .past ? "" : item.exam.seatText].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.exam.course).font(.headline)
                Spacer()
                if item.status != .past, let badge { badge.font(.subheadline.bold()) }
            }
            Text(item.timeLine()).font(.subheadline)
            if !detail.isEmpty {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .opacity(item.status == .past ? 0.6 : 1)
        .padding(.vertical, 2)
    }

    private var badge: Text? {
        guard item.isUrgent(), let text = item.countdownText() else { return nil }
        return Text(text).foregroundStyle(.red)
    }
}
