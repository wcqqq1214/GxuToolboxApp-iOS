import GxuAuth
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
                Section {
                    TermPicker(year: yearBinding, term: termBinding)
                    if let error = model.error {
                        ErrorBanner(message: error.userMessage) { Task { await model.load() } }
                    }
                }
                if model.hasData {
                    section("即将开考", model.sections.upcoming)
                    section("已结束", model.sections.past)
                } else if model.isLoading {
                    HStack { Spacer(); ProgressView("正在查询考试安排…"); Spacer() }
                        .listRowSeparator(.hidden)
                } else if model.error == nil {
                    ContentUnavailableView("本学期暂无考试安排", systemImage: "calendar")
                        .listRowSeparator(.hidden)
                }
            }
            .navigationTitle("考试信息")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: model.term) { await model.load() }
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
                badge
            }
            Label(timeText, systemImage: "clock")
            Label(item.exam.classroom.isEmpty ? "未知" : item.exam.classroom, systemImage: "building.2")
            if item.status != .past {
                Label(item.exam.seat.isEmpty ? "未知" : item.exam.seat, systemImage: "chair")
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
        f.dateFormat = "MM月dd日 HH:mm"
        return f.string(from: date)
    }

    private var badge: some View {
        let (text, color): (String, Color) = switch item.status {
        case .upcoming: (item.countdownText() ?? "即将开考", .red)
        case .past: ("已结束", .gray)
        case .tbd: ("时间未知", .orange)
        }
        return Text(text)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}
