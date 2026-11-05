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
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if model.hasData {
                    section("即将开考", model.sections.upcoming)
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
            .task { await model.resolveInitialTerm() }
            .task(id: LoadKey(value: model.term, ready: model.isReady)) { await model.load() }
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
                    Text("\(title) · \(items.count)门")
                }
            }
        }
    }
}

private struct ExamRow: View {
    let item: ExamItem

    /// 考场、座位号：有才写，同一行用 · 分隔。时间和类型各只出现一次（类型"期末考试"等不显示）
    private var detail: String {
        [item.exam.classroom, item.status == .past ? "" : ExamSeat.text(item.exam.seat)].filter { !$0.isEmpty }.joined(separator: " · ")
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

            Label(timeText, systemImage: "clock")
            Label(item.exam.classroom.isEmpty ? "未知" : item.exam.classroom, systemImage: "building.2")
            if item.status != .past, !item.exam.seatText.isEmpty {
                Label(item.exam.seatText, systemImage: "chair")   // 教务已不提供座位号，没有就不占一行
            }
        }
        .opacity(item.status == .past ? 0.6 : 1)
        .padding(.vertical, 2)
    }

    /// 徽章只给"今日 / 明日开考"（红）和"时间未知"（橙）；更远的考试日期已写在时间行里，不再重复"N天后"
    private var badge: Text? {
        if item.status == .tbd { return Text("时间未知").foregroundStyle(.orange) }
        guard item.isUrgent(), let text = item.countdownText() else { return nil }
        return Text(text).foregroundStyle(.red)
    }
}
