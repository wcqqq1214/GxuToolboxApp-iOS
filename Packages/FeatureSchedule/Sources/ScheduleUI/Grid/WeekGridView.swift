import GxuDesign
import ScheduleKit
import SwiftUI

/// 一周的课表网格：左侧节次，顶部星期和日期，今天一列高亮，当前时间线。
struct WeekGridView: View {
    let week: Int
    let model: ScheduleViewModel
    let onSelect: (ConflictGroup) -> Void
    var onSelectExam: (GridExam) -> Void = { _ in }

    static let timeColumnWidth: CGFloat = 40
    static let rowHeight: CGFloat = 64
    static let headerHeight: CGFloat = 54

    @State private var position = ScrollPosition(edge: .top)
    @Environment(\.gxuAccessoryHeight) private var accessoryHeight

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                WeekBody(week: week, model: model, onSelect: onSelect, onSelectExam: onSelectExam)
                PracticeSection(courses: model.practiceCourses(inWeek: week))
            }
            .padding(.bottom, GxuDesign.Spacing.s)
        }
        .scrollPosition($position)
        .onAppear(perform: scrollToNow)
        .contentMargins(.bottom, 170 + accessoryHeight, for: .scrollContent)   // 滚到底时要能完整露出内容：避开标签栏、附件和“回到本周”
        .scrollIndicators(.hidden)
        .refreshable { await model.refresh() }
        // 网格是定高布局，限制字体放大范围避免文字溢出课程块
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

extension WeekGridView {
    /// 看本周时，直接滚到当前时间附近（像系统日历）。当前时间在前 3 节以内就停在顶部。
    private func scrollToNow() {
        #if DEBUG
        // 截图自查：`-GxuScheduleScrollEnd` 直接滚到底（看网格下方的实践课）
        if CommandLine.arguments.contains("-GxuScheduleScrollEnd") {
            Task { try? await Task.sleep(for: .seconds(1)); position.scrollTo(edge: .bottom) }
            return
        }
        if CommandLine.arguments.contains("-GxuScheduleScrollTop") { return }
        #endif
        guard let termCalendar = model.termCalendar, termCalendar.week(containing: .now) == week else { return }
        let rows = PeriodRows.position(at: .now, calendar: termCalendar.calendar)
        guard rows > 3 else { return }
        position.scrollTo(y: (rows - 3) * Self.rowHeight)
    }
}

/// 星期 + 日期表头。放在分页器外面，随当前周更新，不随页滑动。
struct WeekHeader: View {
    let week: Int
    let termCalendar: TermCalendar?
    /// 这一周里有补班课的星期
    var makeupDays: Set<Int> = []

    var body: some View {
        HStack(spacing: 0) {
            Text(monthText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: WeekGridView.timeColumnWidth)
            ForEach(1...7, id: \.self) { weekday in
                DayHeader(
                    weekday: weekday, date: termCalendar?.date(week: week, weekday: weekday),
                    calendar: termCalendar?.calendar ?? .current, isMakeup: makeupDays.contains(weekday)
                )
            }
        }
        .frame(height: WeekGridView.headerHeight)
        .background(.background)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var monthText: String {
        guard let termCalendar else { return "" }
        return "\(termCalendar.calendar.component(.month, from: termCalendar.date(week: week, weekday: 1)))月"
    }
}

private struct DayHeader: View {
    let weekday: Int
    let date: Date?
    let calendar: Calendar
    var isMakeup = false

    private var isToday: Bool { date.map { calendar.isDateInToday($0) } ?? false }

    var body: some View {
        VStack(spacing: 3) {
            Text(WeekdayName.short(weekday))
                .font(.caption2)
                .foregroundStyle(isToday ? Color.accentColor : .secondary)
            Text(date.map { "\(calendar.component(.day, from: $0))" } ?? "–")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(isToday ? Color.white : .primary)
                .frame(width: 26, height: 26)
                .background { if isToday { Circle().fill(Color.accentColor) } }
                .overlay(alignment: .topTrailing) {
                    if isMakeup {
                        Text("补")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.orange, in: Circle())
                            .offset(x: 9, y: -5)
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let day = date.map { "\(calendar.component(.month, from: $0))月\(calendar.component(.day, from: $0))日" } ?? ""
        return "\(WeekdayName.full(weekday)) \(day)\(isToday ? "，今天" : "")\(isMakeup ? "，补班" : "")"
    }
}

struct WeekBody: View {
    let week: Int
    let model: ScheduleViewModel
    let onSelect: (ConflictGroup) -> Void
    var onSelectExam: (GridExam) -> Void = { _ in }
    @Environment(SchedulePreferencesStore.self) private var preferences

    private let rowHeight = WeekGridView.rowHeight

    var body: some View {
        GeometryReader { proxy in
            let columnWidth = (proxy.size.width - WeekGridView.timeColumnWidth) / 7
            ZStack(alignment: .topLeading) {
                TimeColumn(rowHeight: rowHeight)
                // 今天这一列在假期色带下面不再铺底色（否则两层颜色叠成一块浑浊的矩形），表头日期的高亮保留
                TodayColumn(
                    week: week, termCalendar: model.termCalendar, columnWidth: columnWidth, height: rowHeight * CGFloat(PeriodRows.count),
                    coveredWeekdays: Set(model.index.dayBlocks(inWeek: week).map(\.weekday))
                )

                // 连续的假期合并成一条横跨的色带，文字只出现一次
                ForEach(DayRun.runs(model.index.dayBlocks(inWeek: week))) { run in
                    DayBlockView(run: run)
                        .frame(width: columnWidth * CGFloat(run.days) - 3, height: rowHeight * CGFloat(PeriodRows.count) - 3)
                        .offset(x: WeekGridView.timeColumnWidth + CGFloat(run.firstWeekday - 1) * columnWidth + 1.5, y: 1.5)
                }

                ForEach(1...7, id: \.self) { weekday in
                    // 补课日被调过来的课和原有的课是两个独立的冲突组（RN v2.2），重叠时由 GroupLane 并排显示
                    let dayItems = model.index.items(inWeek: week, weekday: weekday)
                    let groups = ScheduleExpander.conflictGroups(dayItems.filter { !$0.isMakeup }) + ScheduleExpander.conflictGroups(dayItems.filter(\.isMakeup))
                    let exams = model.index.examBlocks(inWeek: week, weekday: weekday)
                    // 课程组和考试块在同一天里重叠时并排（各自独立的图层，不互相吞并）
                    let lanes = LaneLayout.assign(
                        groups.map { (id: $0.id, rows: PeriodRows.rows(begin: $0.begin, end: $0.end)) }
                            + exams.map { (id: "exam-\($0.id)", rows: PeriodRows.rows(begin: $0.begin, end: $0.end)) }
                    )
                    ForEach(groups) { group in
                        let rows = PeriodRows.rows(begin: group.begin, end: group.end)
                        let placed = lanes[group.id] ?? (lane: 0, count: 1)
                        let laneWidth = columnWidth / CGFloat(placed.count)
                        CourseBlock(
                            group: group, selected: group.selected(choices: model.choices), colors: model.colors, rowHeight: rowHeight,
                            showVenue: preferences.value.showVenueInBlock, showTeacher: preferences.value.showTeacherInBlock,
                            attendance: model.attendance?.status(for: group.selected(choices: model.choices))
                        )
                            .frame(width: laneWidth - 3, height: CGFloat(rows.count) * rowHeight - 3)
                            .offset(
                                x: WeekGridView.timeColumnWidth + CGFloat(weekday - 1) * columnWidth + CGFloat(placed.lane) * laneWidth + 1.5,
                                y: CGFloat(rows.lowerBound - 1) * rowHeight + 1.5
                            )
                            .onTapGesture { onSelect(group) }
                    }
                    ForEach(exams) { block in
                        let rows = PeriodRows.rows(begin: block.begin, end: block.end)
                        let placed = lanes["exam-\(block.id)"] ?? (lane: 0, count: 1)
                        let laneWidth = columnWidth / CGFloat(placed.count)
                        ExamBlockView(block: block, rows: rows.count)
                            .frame(width: laneWidth - 3, height: CGFloat(rows.count) * rowHeight - 3)
                            .offset(
                                x: WeekGridView.timeColumnWidth + CGFloat(weekday - 1) * columnWidth + CGFloat(placed.lane) * laneWidth + 1.5,
                                y: CGFloat(rows.lowerBound - 1) * rowHeight + 1.5
                            )
                            .onTapGesture { onSelectExam(block.exam) }
                    }
                }

                if let termCalendar = model.termCalendar, termCalendar.week(containing: .now) == week {
                    NowLine(rowHeight: rowHeight, calendar: termCalendar.calendar)
                }
            }
        }
        .frame(height: rowHeight * CGFloat(PeriodRows.count))
    }
}

private struct TimeColumn: View {
    let rowHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(PeriodRows.all, id: \.index) { period in
                ZStack(alignment: .top) {
                    Rectangle().fill(Color(.separator).opacity(0.5)).frame(height: 0.5)
                    // 节次 + 上课 + 下课时间（和 RN 的 TimeSchedule 一致）
                    VStack(spacing: 0) {
                        Text(period.label)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(period.startText)
                        Text(period.endText)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.8)
                    .monospacedDigit()
                    .padding(.top, 6)
                    .frame(width: WeekGridView.timeColumnWidth)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: rowHeight)
                // 上午 / 下午 / 晚上之间加粗一点分隔，帮助定位
                .overlay(alignment: .top) {
                    if period.first == 5 || period.first == 9 {
                        Rectangle().fill(Color(.separator)).frame(height: 1)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct TodayColumn: View {
    let week: Int
    let termCalendar: TermCalendar?
    let columnWidth: CGFloat
    let height: CGFloat
    var coveredWeekdays: Set<Int> = []

    var body: some View {
        if let termCalendar, termCalendar.week(containing: .now) == week, !coveredWeekdays.contains(termCalendar.weekday(of: .now)) {
            let weekday = termCalendar.weekday(of: .now)
            Rectangle()
                .fill(Color.accentColor.opacity(0.07))
                .frame(width: columnWidth, height: height)
                .offset(x: WeekGridView.timeColumnWidth + CGFloat(weekday - 1) * columnWidth)
                .accessibilityHidden(true)
        }
    }
}

/// 当前时间线（像系统日历那样的红线），每分钟更新
private struct NowLine: View {
    let rowHeight: CGFloat
    let calendar: Calendar

    var body: some View {
        TimelineView(.everyMinute) { context in
            let y = PeriodRows.position(at: context.date, calendar: calendar) * rowHeight
            HStack(spacing: 0) {
                Circle().fill(.red).frame(width: 7, height: 7)
                Rectangle().fill(.red).frame(height: 1)
            }
            .padding(.leading, WeekGridView.timeColumnWidth - 3.5)
            .offset(y: y - 3.5)
            .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
    }
}

/// 同一天里显示行相同或相交的块并排分栏，不重叠、不丢失。输入是 (id, 占用的显示行)，输出每个 id 的栏号和该簇的总栏数。
enum LaneLayout {
    static func assign(_ items: [(id: String, rows: ClosedRange<Int>)]) -> [String: (lane: Int, count: Int)] {
        let sorted = items.sorted { ($0.rows.lowerBound, $0.rows.upperBound, $0.id) < ($1.rows.lowerBound, $1.rows.upperBound, $1.id) }
        var result: [String: (lane: Int, count: Int)] = [:]
        var cluster: [(id: String, lane: Int)] = []
        var laneEnds: [Int] = []
        var clusterEnd = 0

        func flush() {
            let count = max(laneEnds.count, 1)
            for item in cluster { result[item.id] = (item.lane, count) }
            cluster = []
            laneEnds = []
        }

        for item in sorted {
            if !cluster.isEmpty, item.rows.lowerBound > clusterEnd { flush() }
            if let lane = laneEnds.firstIndex(where: { $0 < item.rows.lowerBound }) {
                laneEnds[lane] = item.rows.upperBound
                cluster.append((item.id, lane))
            } else {
                laneEnds.append(item.rows.upperBound)
                cluster.append((item.id, laneEnds.count - 1))
            }
            clusterEnd = cluster.count == 1 ? item.rows.upperBound : max(clusterEnd, item.rows.upperBound)
        }
        flush()
        return result
    }
}
