import ExamKit
import GxuAuth
import GxuDesign
import ScheduleKit
import SwiftUI

/// 首页：今天的课、下一节课、临近的考试、明天预览。用系统的分组列表，卡片内容不用玻璃。
struct HomeView: View {
    let model: HomeModel
    let onRequestLogin: () -> Void
    @Environment(\.services) private var services

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("今天")
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
            GxuErrorView(message) { Task { await model.load(services: services, minimumInterval: 0) } }
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
    private var event: HomeEvent? { HomeEvent.pick(snapshot: snapshot, exams: model.exams, now: now) }
    /// “接下来”卡片只在学期内显示（学期结束 / 未开学时不显示），所以只有真的显示了才从“近期考试”里去重，
    /// 否则这场考试在首页上就哪里都看不到
    private var shownEvent: HomeEvent? { plan.phase == .inTerm ? event : nil }
    /// 正在上或还没上的课
    private var remaining: [CourseOccurrence] { plan.courses.filter { plan.status(of: $0, now: now) != .finished } }
    private var finished: [CourseOccurrence] { plan.courses.filter { plan.status(of: $0, now: now) == .finished } }

    /// 今日课程：没上完的直接列出；上完的折叠起来，全部结束时给一句明确的状态
    @ViewBuilder
    private var todaySection: some View {
        // 放假 / 调休休息日已经有“今天放假…”的提示，不再重复一张“今天没有课”
        if !(plan.courses.isEmpty && plan.note != nil) { todayCoursesSection }
    }

    @ViewBuilder
    private var todayCoursesSection: some View {
        Section(header: Text("今日课程"), footer: coursesFooter) {
            if plan.courses.isEmpty {
                StatusRow(systemImage: plan.note == nil ? "cup.and.saucer" : "sun.max", title: "今天没有课", subtitle: nil)
            } else {
                if remaining.isEmpty {
                    StatusRow(systemImage: "checkmark.circle", title: "今天的课已结束", subtitle: "共 \(plan.courses.count) 节课")
                }
                ForEach(remaining) { item in
                    CourseRow(item: item, status: plan.status(of: item, now: now), colors: model.colors)
                }
                if !finished.isEmpty {
                    DisclosureGroup("已结束的课（\(finished.count)）") {
                        ForEach(finished) { item in CourseRow(item: item, status: .finished, colors: model.colors) }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    var body: some View {
        List {
            // 日期行和大标题、卡片共用 A 线（左边缘）。放在分组标题里而不是列表行里：
            // 列表行的圆角容器会把贴着左边缘的文字裁掉第一个字；分组标题没有这个问题，系统默认缩进到 B 线，这里往回挪一个 cardInset
            Section {} header: {
                DateHeader(plan: plan, termCalendar: snapshot.termCalendar)
                    .padding(.leading, -GxuDesign.Layout.cardInset)
                    .textCase(nil)
            }

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
                if let event = event { Section("接下来") { EventCard(event: event, now: now, colors: model.colors) } }
                todaySection
                if !plan.tomorrow.isEmpty {
                    Section("明天") {
                        ForEach(plan.tomorrow) { item in
                            CourseRow(item: item, status: .upcoming, colors: model.colors)
                        }
                    }
                } else if remaining.isEmpty {
                    Section("明天") { StatusRow(systemImage: "cup.and.saucer", title: "明天没有课", subtitle: nil) }
                }
            }

            // 已经在“接下来”里展示的那场考试不再重复
            let otherExams = model.exams.filter { exam in
                if case .exam(let shown, _) = shownEvent { return shown.id != exam.id }
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

// MARK: 各区块

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

/// 正在上的课 / 下一节课 / 临近考试的大卡片
private struct EventCard: View {
    let event: HomeEvent
    let now: Date
    let colors: [String: UInt32]

    var body: some View {
        VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
            HStack {
                Text(caption).font(.footnote.weight(.semibold)).foregroundStyle(event.isOngoing ? .green : .secondary)
                Spacer()
                Text(trailing).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text(title).font(.title3.weight(.semibold))
            if let detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
            if case .course(let item, true, _) = event {
                ProgressView(value: min(max(now.timeIntervalSince(item.startsAt) / item.endsAt.timeIntervalSince(item.startsAt), 0), 1))
                    .tint(.green)
            }
        }
        .padding(.vertical, GxuDesign.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var caption: String {
        switch event {
        case .course(let item, true, _): item.course.isCustom ? "正在上实验课" : "正在上课"
        case .course(let item, false, _) where item.course.isCustom: "下节实验课"
        case .course(_, false, true): "明天第一节课"
        case .course: "下一节课"
        case .exam(_, true): "考试进行中"
        case .exam: "即将考试"
        case .holiday: "下个假期"
        }
    }

    /// 右上角：“什么时候”，只在这里说一次
    private var trailing: String {
        switch event {
        case .course(let item, true, _): RelativeTime.remaining(until: item.endsAt, now: now)
        case .exam(_, true): ""
        case .holiday(let holiday): holiday.dayText(now: now, calendar: .current)
        default: RelativeTime.untilStart(event.startsAt, now: now)
        }
    }

    private var title: String {
        switch event {
        case .course(let item, _, _): item.course.courseName
        case .exam(let item, _): item.exam.course
        case .holiday(let holiday): holiday.title
        }
    }

    private var detail: String? {
        switch event {
        // 右上角如果已经写了具体时刻（“明天 08:00”），这里就不再写时间；同一张卡片里同一个信息只出现一次
        case .course(let item, _, _):
            [item.sectionText, RelativeTime.showsClock(in: trailing) ? "" : item.timeRangeText, item.course.venueName, item.course.teacher]
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
                Text([item.sectionText, item.timeRangeText, item.course.venueName].filter { !$0.isEmpty }.joined(separator: " · "))
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
