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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.exam.course).font(.headline)
                Spacer()
                if item.status != .past { badge }
            }
            Label(timeText, systemImage: "clock")
            Label(item.exam.classroom.isEmpty ? "未知" : item.exam.classroom, systemImage: "building.2")
            if item.status != .past, !item.exam.seat.isEmpty {
                Label(item.exam.seat, systemImage: "chair")   // 教务已不提供座位号，没有就不占一行
            }
            Text(item.exam.type).font(.caption).foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .opacity(item.status == .past ? 0.6 : 1)
        .padding(.vertical, 2)
    }

    private var timeText: String {
        guard let date = item.date else { return item.exam.time.isEmpty ? "时间未定" : item.exam.time }
        let f = DateFormatter()
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: date)
    }

    /// 只有今日、明日开考用红色；更远的用主题色；时间未知用橙色。已结束的行不显示徽章
    private var badge: some View {
        let urgent = item.isUrgent()
        let text: String = switch item.status {
        case .upcoming: item.countdownText() ?? "即将开考"
        case .past: ""
        case .tbd: "时间未知"
        }
        let tint: Color = item.status == .tbd ? .orange : (urgent ? .red : .accentColor)
        return Text(text)
            .font(.caption.bold())
            .foregroundStyle(urgent || item.status == .tbd ? Color.white : tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(urgent || item.status == .tbd ? tint : tint.opacity(0.15), in: Capsule())
    }
}
