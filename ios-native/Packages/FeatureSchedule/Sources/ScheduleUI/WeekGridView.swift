import GxuDesign
import ScheduleKit
import SwiftUI

/// 一周的课表网格：左侧节次，顶部星期和日期，今天一列高亮，当前时间线。
struct WeekGridView: View {
    let week: Int
    let model: ScheduleViewModel
    let onSelect: (ConflictGroup) -> Void

    static let timeColumnWidth: CGFloat = 40
    static let rowHeight: CGFloat = 64
    static let headerHeight: CGFloat = 54

    @State private var position = ScrollPosition(edge: .top)

    var body: some View {
        ScrollView {
            WeekBody(week: week, model: model, onSelect: onSelect)
                .padding(.bottom, GxuDesign.Spacing.s)
        }
        .scrollPosition($position)
        .onAppear(perform: scrollToNow)
        .contentMargins(.bottom, 96, for: .scrollContent)   // 给浮动控件留位置
        .scrollIndicators(.hidden)
        .refreshable { await model.refresh() }
        // 网格是定高布局，限制字体放大范围避免文字溢出课程块
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

extension WeekGridView {
    /// 看本周时，直接滚到当前时间附近（像系统日历）。当前时间在前 3 节以内就停在顶部。
    private func scrollToNow() {
        guard let termCalendar = model.termCalendar, termCalendar.week(containing: .now) == week else { return }
        let rows = ClassPeriods.position(at: .now, calendar: termCalendar.calendar)
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
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 13, height: 13)
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

private struct WeekBody: View {
    let week: Int
    let model: ScheduleViewModel
    let onSelect: (ConflictGroup) -> Void
    @Environment(SchedulePreferencesStore.self) private var preferences

    private let rowHeight = WeekGridView.rowHeight

    var body: some View {
        GeometryReader { proxy in
            let columnWidth = (proxy.size.width - WeekGridView.timeColumnWidth) / 7
            ZStack(alignment: .topLeading) {
                TimeColumn(rowHeight: rowHeight)
                TodayColumn(week: week, termCalendar: model.termCalendar, columnWidth: columnWidth, height: rowHeight * CGFloat(ClassPeriods.count))

                ForEach(model.index.dayBlocks(inWeek: week)) { block in
                    DayBlockView(block: block)
                        .frame(width: columnWidth - 3, height: rowHeight * CGFloat(ClassPeriods.count) - 3)
                        .offset(x: WeekGridView.timeColumnWidth + CGFloat(block.weekday - 1) * columnWidth + 1.5, y: 1.5)
                }

                ForEach(1...7, id: \.self) { weekday in
                    let groups = ScheduleExpander.conflictGroups(model.index.items(inWeek: week, weekday: weekday))
                    ForEach(groups) { group in
                        CourseBlock(
                            group: group, selected: group.selected(choices: model.choices), colors: model.colors, rowHeight: rowHeight,
                            showVenue: preferences.value.showVenueInBlock, showTeacher: preferences.value.showTeacherInBlock
                        )
                            .frame(width: columnWidth - 3, height: CGFloat(group.end - group.begin + 1) * rowHeight - 3)
                            .offset(
                                x: WeekGridView.timeColumnWidth + CGFloat(weekday - 1) * columnWidth + 1.5,
                                y: CGFloat(group.begin - 1) * rowHeight + 1.5
                            )
                            .onTapGesture { onSelect(group) }
                    }
                }

                if let termCalendar = model.termCalendar, termCalendar.week(containing: .now) == week {
                    NowLine(rowHeight: rowHeight, calendar: termCalendar.calendar)
                }
            }
        }
        .frame(height: rowHeight * CGFloat(ClassPeriods.count))
    }
}

private struct TimeColumn: View {
    let rowHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ClassPeriods.all, id: \.number) { period in
                ZStack(alignment: .top) {
                    Rectangle().fill(Color(.separator).opacity(0.5)).frame(height: 0.5)
                    VStack(spacing: 1) {
                        Text("\(period.number)").font(.footnote.weight(.semibold))
                        Text(period.startText).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    .monospacedDigit()
                    .padding(.top, 8)
                    .frame(width: WeekGridView.timeColumnWidth)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: rowHeight)
                // 上午 / 下午 / 晚上之间加粗一点分隔，帮助定位
                .overlay(alignment: .top) {
                    if period.number == 5 || period.number == 9 {
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

    var body: some View {
        if let termCalendar, termCalendar.week(containing: .now) == week {
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
            let y = ClassPeriods.position(at: context.date, calendar: calendar) * rowHeight
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
