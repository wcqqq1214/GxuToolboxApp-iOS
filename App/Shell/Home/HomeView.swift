import ExamKit
import GxuAuth
import GxuDesign
import ScheduleKit
import SwiftUI

struct HomeView: View {
    let model: HomeModel
    let onRequestLogin: () -> Void
    @Environment(\.services) private var services

    var body: some View {
        NavigationStack {
            content
                .gxuPageBackground()
                .navigationTitle("今天")
                .toolbar(.hidden, for: .tabBar)
                .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .needsLogin:
            GxuEmptyView(
                "还没有登录教务系统", systemImage: "person.crop.circle.badge.questionmark",
                message: "登录后即可查看今天的课和考试", actionTitle: "去登录", action: onRequestLogin
            )
        case .loading:
            GxuLoadingView("正在加载…")
        case .unavailable(let message):
            VStack(spacing: GxuDesign.Spacing.l) {
                TimelineView(.everyMinute) { context in
                    if let event = model.nextEvent(now: context.date) {
                        EventCard(event: event, now: context.date, colors: model.colors)
                            .padding(.horizontal, GxuDesign.Spacing.l)
                    }
                }
                GxuErrorView(message) { Task { await model.load(services: services, minimumInterval: 0) } }
            }
        case .ready:
            if let snapshot = model.snapshot {
                TimelineView(.everyMinute) { context in
                    HomeList(model: model, snapshot: snapshot, now: context.date)
                }
                .refreshable { await model.load(services: services, minimumInterval: 0) }
            }
        }
    }
}

private struct HomeList: View {
    let model: HomeModel
    let snapshot: ScheduleSnapshot
    let now: Date

    private var plan: TodayPlan { snapshot.todayPlan(now: now) }
    private var event: HomeEvent? { model.nextEvent(now: now) }
    private var remaining: [CourseOccurrence] { plan.courses.filter { plan.status(of: $0, now: now) != .finished } }
    private var finished: [CourseOccurrence] { plan.courses.filter { plan.status(of: $0, now: now) == .finished } }

    @ViewBuilder
    private var todaySection: some View {
        if !(plan.courses.isEmpty && plan.note != nil) { todayCoursesSection }
    }

    @ViewBuilder
    private var todayCoursesSection: some View {
        Section(header: Text("今日课程"), footer: coursesFooter) {
            if plan.courses.isEmpty {
                StatusRow(systemImage: "cup.and.saucer", title: "没有课", subtitle: nil)
            } else {
                ForEach(remaining) { item in
                    CourseRow(item: item, status: plan.status(of: item, now: now), colors: model.colors)
                }
                if !finished.isEmpty {
                    DisclosureGroup(remaining.isEmpty ? "全部结束（\(finished.count) 节）" : "已结束的课（\(finished.count)）") {
                        ForEach(finished) { item in CourseRow(item: item, status: .finished, colors: model.colors) }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    var body: some View {
        List {
            Section {} header: {
                DateHeader(plan: plan, termCalendar: snapshot.termCalendar)
                    .padding(.leading, -GxuDesign.Layout.cardInset)
                    .textCase(nil)
            }

            if let event { Section(event.isOngoing ? "正在进行" : "接下来") { EventCard(event: event, now: now, colors: model.colors) } }

            switch plan.phase {
            case .beforeTerm(let days):
                Section {
                    StatusRow(systemImage: "calendar.badge.clock", title: "距开学还有 \(days) 天", subtitle: "开学后这里会显示每天的课程")
                }
            case .afterTerm:
                Section {
                    StatusRow(systemImage: "checkmark.seal", title: "本学期已结束", subtitle: "新学期的课表发布后会自动更新")
                }
            case .inTerm:
                if let note = plan.note { Section { NoteRow(note: note) } }
                todaySection
                if !plan.tomorrow.isEmpty {
                    Section("明天") {
                        ForEach(plan.tomorrow) { item in
                            CourseRow(item: item, status: .upcoming, colors: model.colors)
                        }
                    }
                } else if remaining.isEmpty {
                    Section("明天") { StatusRow(systemImage: "cup.and.saucer", title: "没有课", subtitle: nil) }
                }
            }

            let otherExams = model.exams(at: now).filter { exam in
                guard let end = exam.endsAt, now < end else { return false }
                if case .exam(let shown, _) = event { return shown.id != exam.id }
                return true
            }
            if !otherExams.isEmpty {
                Section("近期考试") {
                    ForEach(otherExams) { ExamRow(item: $0, now: now) }
                }
            }
        }
        .listSectionSpacing(.compact)
    }

    @ViewBuilder
    private var coursesFooter: some View {
        if let updated = Optional(snapshot.updatedAt) {
            Text("课表更新于 \(updated.formatted(.dateTime.month().day().hour().minute().locale(Locale(identifier: "zh_CN"))))")
        }
    }
}


private struct DateHeader: View {
    let plan: TodayPlan
    let termCalendar: TermCalendar

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(plan.date.formatted(.dateTime.month(.wide).day().weekday(.wide).locale(Locale(identifier: "zh_CN"))))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.primary)
            if let week = plan.week {
                Text("第 \(week) 周")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct NoteRow: View {
    let note: TodayPlan.DayNote

    var body: some View {
        switch note {
        case .holiday(let name):
            Label("今天放假 · \(name)", systemImage: "sun.max").foregroundStyle(.green)
        case .rest:
            Label("调休休息日，今天没有课", systemImage: "moon.zzz").foregroundStyle(.green)
        case .makeup(let from):
            Label(
                "补班：今天按\(from.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN"))))的课表上课",
                systemImage: "arrow.triangle.swap"
            ).foregroundStyle(.orange)
        }
    }
}

private struct StatusRow: View {
    let systemImage: String
    let title: String
    let subtitle: String?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(.secondary) }
            }
        } icon: {
            Image(systemName: systemImage).frame(width: 28)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }
}

private struct EventCard: View {
    let event: HomeEvent
    let now: Date
    let colors: [String: UInt32]

    var body: some View {
        let caption = caption
        VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                if let caption {
                    Text(caption).font(.footnote.weight(.semibold)).foregroundStyle(event.isOngoing ? .green : .secondary)
                } else {
                    Text(title).font(.title3.weight(.semibold))
                }
                Spacer()
                Text(trailing).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            }
            if caption != nil { Text(title).font(.title3.weight(.semibold)) }
            if let detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
            if case .course(let item, true) = event {
                ProgressView(value: min(max(now.timeIntervalSince(item.startsAt) / item.endsAt.timeIntervalSince(item.startsAt), 0), 1))
                    .tint(.green)
            }
        }
        .padding(.vertical, GxuDesign.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var caption: String? {
        switch event {
        case .course(_, true): "正在上课"
        case .course: nil
        case .exam(_, true): "考试进行中"
        case .exam: "考试"
        case .holiday: event.isOngoing ? "正在放假" : "假期"
        }
    }

    private var trailing: String {
        switch event {
        case .course(let item, true): RelativeTime.remaining(until: item.endsAt, now: now)
        case .exam(_, true): ""
        case .holiday(let holiday): holiday.isOngoing ? "" : holiday.dayText(now: now, calendar: .current)
        default: RelativeTime.untilStart(event.startsAt, now: now)
        }
    }

    private var title: String {
        switch event {
        case .course(let item, _): item.course.courseName
        case .exam(let item, _): item.exam.course
        case .holiday(let holiday): holiday.displayTitle
        }
    }

    private var detail: String? {
        switch event {
        case .course(let item, _):
            [item.sectionText, RelativeTime.showsClock(in: trailing) ? "" : item.timeRangeText, item.course.locationText, item.course.teacher]
                .filter { !$0.isEmpty }.joined(separator: " · ")
        case .exam(let item, _):
            [item.exam.classroom, item.exam.seatText, item.exam.type].filter { !$0.isEmpty }.joined(separator: " · ")
        case .holiday: nil
        }
    }
}

private struct CourseRow: View {
    let item: CourseOccurrence
    let status: TodayPlan.CourseStatus
    let colors: [String: UInt32]

    var body: some View {
        HStack(spacing: GxuDesign.Spacing.m) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(CourseTint(hex: colors[item.course.courseName] ?? 0xC7CEEA).marker)
                .frame(width: 5, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.course.courseName).font(.body.weight(.medium))
                    if item.isMakeup { Tag("补班", color: .orange) }
                    if status == .ongoing { Tag("上课中", color: .green) }
                }
                Text([item.sectionText, item.timeRangeText, item.course.locationText].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .opacity(status == .finished ? 0.45 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(status == .finished ? "已结束" : status == .ongoing ? "进行中" : "")
    }
}

private struct ExamRow: View {
    let item: ExamItem
    let now: Date

    var body: some View {
        HStack(spacing: GxuDesign.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.exam.course).font(.body.weight(.medium))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let countdown = item.countdownText(now: now) {
                Text(countdown).font(.footnote.weight(.semibold)).foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let when = item.date.map { $0.formatted(.dateTime.month().day().weekday().locale(Locale(identifier: "zh_CN"))) + " " + RelativeTime.clock($0) } ?? item.exam.time
        return [when, item.exam.classroom, item.exam.seatText].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

private struct Tag: View {
    let text: String
    let color: Color
    init(_ text: String, color: Color) { (self.text, self.color) = (text, color) }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
    }
}
