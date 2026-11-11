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
                    Section { TermRow(model: model) }
                    Section {
                        Picker("内容", selection: $model.mode) {
                            Text("考勤课表").tag(AttendanceViewModel.Mode.schedule)
                            Text("考勤记录").tag(AttendanceViewModel.Mode.records)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
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
            .gxuHidesTabChrome()
            .task { await model.resolveContext() }
            .task(id: LoadKey(mode: model.mode, selection: model.selection, week: model.week, ready: model.isReady)) { await model.load() }
            .refreshable { await model.load() }
        }

        private struct LoadKey: Hashable {
            var mode: AttendanceViewModel.Mode
            var selection: AttendanceViewModel.Selection
            var week: Int
            var ready: Bool
        }


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


        @ViewBuilder
        private var records: some View {
            if model.records.isEmpty {
                if model.isLoading {
                    GxuLoadingView("正在查询考勤记录…").frame(minHeight: 240).listRowBackground(Color.clear)
                } else if model.error == nil {
                    GxuEmptyView("本学期暂无考勤记录", systemImage: "checkmark.circle").listRowBackground(Color.clear)
                }
            } else {
                Section {
                    Picker("筛选", selection: $model.recordFilter) {
                        Text("全部记录").tag(AttendanceFilter.all)
                        Text("异常和最近 7 天").tag(AttendanceFilter.abnormalAndRecent)
                        Text("只看异常").tag(AttendanceFilter.abnormal)
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text("本学期共有 \(model.abnormalCount) 条迟到或缺勤记录。")
                }
                let visibleRecords = model.visibleRecords
                if visibleRecords.isEmpty {
                    GxuEmptyView(
                        model.recordFilter == .abnormal ? "本学期没有迟到或缺勤记录" : "当前筛选范围内暂无考勤记录",
                        systemImage: "checkmark.circle"
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(AttendanceDayGroup.group(visibleRecords)) { group in
                        Section(group.title) {
                            ForEach(group.records) { RecordRow(record: $0) }
                        }
                    }
                }
            }
        }


        @ViewBuilder
        private var schedule: some View {
            Section {
                HStack {
                    Button("上一周", systemImage: "chevron.left") { model.week = max(1, model.week - 1) }
                        .labelStyle(.iconOnly).disabled(model.week <= 1)
                    Spacer()
                    Text("第 \(model.week) 周").font(.headline)
                    Spacer()
                    Button("下一周", systemImage: "chevron.right") { model.week = min(model.totalWeeks, model.week + 1) }
                        .labelStyle(.iconOnly).disabled(model.week >= model.totalWeeks)
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
            ForEach(AttendanceDayGroup.groupCourses(model.courses)) { group in
                Section(group.title) {
                    ForEach(group.courses) { CourseRow(course: $0, state: model.state(of: $0)) }
                }
            }
        }
    }
}

private struct TermRow: View {
    @Bindable var model: AttendanceViewModel

    private var termName: String { model.selection.term == 1 ? "秋季" : "春季" }

    var body: some View {
        LabeledContent("学期") {
            Menu {
                Picker("学年", selection: $model.selection.year) {
                    ForEach(model.years.contains(model.selection.year) ? model.years : (model.years + [model.selection.year]).sorted(), id: \.self) {
                        Text(verbatim: "\($0)–\($0 + 1) 学年").tag($0)
                    }
                }
                Picker("学期", selection: $model.selection.term) {
                    Text("秋季").tag(1)
                    Text("春季").tag(2)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(verbatim: "\(model.selection.year)–\(model.selection.year + 1) \(termName)")
                    Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
                }
            }
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

private struct RecordRow: View {
    let record: AttendanceRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.state.symbol).foregroundStyle(record.state.tint).font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.courseName).font(.headline)
                Text([record.periodText, record.roomName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.statusName.isEmpty ? record.state.label : record.statusName).font(.subheadline).foregroundStyle(record.state.tint)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
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
                Text(["第\(course.firstPeriod)–\(course.lastPeriod)节", timeText].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
                if !course.room.isEmpty { Text(course.room).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
            if let state {
                Label(state.label, systemImage: state.symbol)
                    .font(.subheadline).foregroundStyle(state.tint)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
