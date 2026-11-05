import FeatureAccount
import GxuAuth
import GxuDesign
import GxuFoundation
import ScheduleKit
import SwiftUI

public struct AttendanceView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View { Content(services: services) }

    private struct Content: View {
        @State private var model: AttendanceViewModel

        init(services: AppServices) { _model = State(initialValue: AttendanceViewModel(services: services)) }

        var body: some View {
            List {
                if model.access != .ok {
                    needsLogin
                } else {
                    Section {
                        Picker("内容", selection: $model.mode) {
                            Text("考勤记录").tag(AttendanceViewModel.Mode.records)
                            Text("考勤课表").tag(AttendanceViewModel.Mode.schedule)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    if let error = model.error {
                        GxuErrorView(error.userMessage) { Task { await model.load() } }.listRowBackground(Color.clear)
                    }
                    switch model.mode {
                    case .records: records
                    case .schedule: schedule
                    }
                }
            }
            .navigationTitle("考勤查询")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { if model.access == .ok { calendarMenu } }
            .task(id: LoadKey(mode: model.mode, calendarId: model.calendarId, week: model.week)) { await model.load() }
            .refreshable { await model.load() }
        }

        private struct LoadKey: Hashable {
            var mode: AttendanceViewModel.Mode
            var calendarId: Int?
            var week: Int
        }

        // MARK: 需要登录

        @ViewBuilder
        private var needsLogin: some View {
            GxuEmptyView(
                model.access == .expired ? "考勤登录已过期" : "还没有登录考勤账号",
                systemImage: "person.badge.clock",
                message: "考勤系统登录需要验证码，登录后再回来查看。"
            )
            .listRowBackground(Color.clear)
            Section {
                NavigationLink("去登录考勤账号") { AccountFeature.makeAttendanceAccountView() }
            }
        }

        // MARK: 记录

        @ViewBuilder
        private var records: some View {
            let groups = AttendanceDayGroup.group(model.records)
            if model.records.isEmpty {
                if model.isLoading {
                    GxuLoadingView("正在查询考勤记录…").frame(minHeight: 240).listRowBackground(Color.clear)
                } else if model.error == nil {
                    GxuEmptyView("本学期暂无考勤记录", systemImage: "checkmark.circle").listRowBackground(Color.clear)
                }
            } else {
                Section { SummaryRow(summary: model.summary) } header: { Text("共 \(model.totalRecords) 条") }
                ForEach(groups) { group in
                    Section(group.title) {
                        ForEach(group.records) { RecordRow(record: $0) }
                    }
                }
                if model.hasMore {
                    ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
                        .task { await model.loadMore() }
                }
            }
        }

        // MARK: 课表

        @ViewBuilder
        private var schedule: some View {
            Section {
                HStack {
                    Button("上一周", systemImage: "chevron.left") { model.week = max(1, model.week - 1) }
                        .labelStyle(.iconOnly).disabled(model.week <= 1)
                    Spacer()
                    Text("第 \(model.week) 周").font(.headline)
                    Spacer()
                    Button("下一周", systemImage: "chevron.right") { model.week = min(model.calendar?.weekTotal ?? 20, model.week + 1) }
                        .labelStyle(.iconOnly).disabled(model.week >= (model.calendar?.weekTotal ?? 20))
                }
                .buttonStyle(.borderless)
            }
            if model.courses.isEmpty {
                if model.isLoading {
                    GxuLoadingView("正在查询考勤课表…").frame(minHeight: 200).listRowBackground(Color.clear)
                } else if model.error == nil {
                    GxuEmptyView("这一周没有课", systemImage: "calendar").listRowBackground(Color.clear)
                }
            }
            ForEach(Dictionary(grouping: model.courses, by: \.weekday).keys.sorted(), id: \.self) { weekday in
                let items = model.courses.filter { $0.weekday == weekday }
                Section("周\(WeekdayName.short(weekday)) · \(items.first.map { String($0.day.suffix(5)).replacingOccurrences(of: "-", with: "/") } ?? "")") {
                    ForEach(items) { CourseRow(course: $0, state: model.state(of: $0)) }
                }
            }
        }

        private var calendarMenu: some View {
            Menu {
                Picker("学期", selection: $model.calendarId) {
                    ForEach(model.calendars.sorted { $0.calendarName > $1.calendarName }) { Text(Self.name($0)).tag(Int?.some($0.calendarId)) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(model.calendar.map(Self.name) ?? "学期")
                    Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
                }
            }
            .disabled(model.calendars.isEmpty)
        }

        /// `2025-1` → `2025–2026 秋季`
        static func name(_ c: AttendanceCalendar) -> String {
            let parts = c.calendarName.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2, let year = parts.first, let term = parts.last else { return c.calendarName }
            return "\(year)–\(year + 1) \(term == 1 ? "秋季" : term == 2 ? "春季" : "小学期")"
        }
    }
}

extension AttendanceState {
    var symbol: String {
        switch self {
        case .normal: "checkmark.circle.fill"
        case .late: "clock.fill"
        case .absent: "xmark.circle.fill"
        case .notStarted: "circle"
        case .noNeed: "minus.circle"
        case .unknown: "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .normal: .green
        case .late: .orange
        case .absent: .red
        case .notStarted, .noNeed, .unknown: .secondary
        }
    }
}

private struct SummaryRow: View {
    let summary: AttendanceSummary

    var body: some View {
        HStack {
            stat("正常", summary.normal, .green)
            stat("迟到", summary.late, .orange)
            stat("缺勤", summary.absent, .red)
            stat("其他", summary.other, .secondary)
        }
    }

    private func stat(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3.bold()).foregroundStyle(color)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecordRow: View {
    let record: AttendanceRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.state.symbol).foregroundStyle(record.state.tint).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.courseName).font(.headline)
                Text([record.periodConnect.isEmpty ? "" : "第\(record.periodConnect)节", record.roomName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.stateName).font(.subheadline).foregroundStyle(record.state.tint)
                if record.atdTime.contains(":") { Text(String(record.atdTime.suffix(8).prefix(5))).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct CourseRow: View {
    let course: AttendanceCourse
    let state: AttendanceState?

    private var timeText: String {
        let first = ClassPeriods.period(course.firstPeriod)?.startText ?? ""
        let last = ClassPeriods.period(course.lastPeriod)?.endText ?? ""
        return first.isEmpty ? "" : "\(first)–\(last)"
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name).font(.headline)
                Text("第\(course.firstPeriod)–\(course.lastPeriod)节 \(timeText)").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if let state {
                Image(systemName: state.symbol).foregroundStyle(state.tint).font(.title3)
            }
        }
        .padding(.vertical, 2)
    }
}
