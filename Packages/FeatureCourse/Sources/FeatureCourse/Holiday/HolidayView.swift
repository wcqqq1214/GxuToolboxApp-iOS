import GxuAuth
import GxuDesign
import ScheduleKit
import SwiftUI

public struct HolidayView: View {
    @Environment(\.services) private var services
    @State private var campus: CampusCalendar?
    @State private var kind: HolidayRange.Kind?

    public init() {}

    private var presentation: (current: [HolidayEntry], past: [HolidayEntry])? {
        guard let campus else { return nil }
        let all = HolidayPresentation.build(campus, now: .now)
        guard let kind else { return all }
        return (all.current.filter { $0.holiday.kind == kind }, all.past.filter { $0.holiday.kind == kind })
    }

    public var body: some View {
        List {
            if let p = presentation {
                if p.current.isEmpty && p.past.isEmpty {
                    GxuEmptyView("暂无节假日安排", systemImage: "sun.max").listRowBackground(Color.clear)
                }
                section(p.current, title: "即将到来")
                section(p.past, title: "已结束")
            } else {
                GxuLoadingView("加载中…").frame(minHeight: 240).listRowBackground(Color.clear)
            }
        }
        .navigationTitle("节假日")
        .navigationBarTitleDisplayMode(.inline)
        .gxuHidesTabChrome()
        .toolbar {
            Menu {
                Picker("类型", selection: $kind) {
                    Text("全部").tag(HolidayRange.Kind?.none)
                    Text("全国").tag(HolidayRange.Kind?.some(.national))
                    Text("地方").tag(HolidayRange.Kind?.some(.local))
                    Text("学校").tag(HolidayRange.Kind?.some(.school))
                }
            } label: {
                Label(kind.map(Self.kindName) ?? "全部", systemImage: "line.3.horizontal.decrease")
            }
        }
        .task { campus = await CampusCalendarRepository(database: services.database).current() }
    }

    static func kindName(_ kind: HolidayRange.Kind) -> String {
        switch kind {
        case .national: "全国"
        case .local: "地方"
        case .school: "学校"
        }
    }

    @ViewBuilder
    private func section(_ entries: [HolidayEntry], title: String) -> some View {
        if !entries.isEmpty {
            Section(title) {
                ForEach(entries) { HolidayRow(entry: $0) }
            }
        }
    }
}

private struct HolidayRow: View {
    let entry: HolidayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.holiday.title).font(.headline)
                Text(HolidayView.kindName(entry.holiday.kind)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let badge { Text(badge).font(.subheadline).foregroundStyle(Color.accentColor) }
            }
            Text("\(entry.rangeText) · 共\(entry.days)天").font(.subheadline).foregroundStyle(.secondary)
            if !entry.makeupDays.isEmpty {
                let cal = Calendar.current
                Text("补班：" + entry.makeupDays.map { DayText.monthDayWeekday($0, calendar: cal) }.joined(separator: "、"))
                    .font(.subheadline).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
        .opacity(entry.status == .past ? 0.6 : 1)
    }

    private var badge: String? {
        switch entry.status {
        case .ongoing: "放假中"
        case .upcoming: nil   // 起止日期已写在下一行，不再重复"N天后"
        case .past: nil
        }
    }
}

public struct TimeShiftView: View {
    @Environment(\.services) private var services
    @State private var campus: CampusCalendar?

    public init() {}

    public var body: some View {
        List {
            if let campus {
                let p = TimeShiftPresentation.build(campus, now: .now)
                if p.current.isEmpty && p.past.isEmpty {
                    GxuEmptyView("暂无调休补班安排", systemImage: "calendar.badge.clock").listRowBackground(Color.clear)
                }
                section(p.current, title: "即将补班")
                section(p.past, title: "已结束")
            } else {
                GxuLoadingView("加载中…").frame(minHeight: 240).listRowBackground(Color.clear)
            }
        }
        .navigationTitle("调休补班")
        .navigationBarTitleDisplayMode(.inline)
        .gxuHidesTabChrome()
        .task { campus = await CampusCalendarRepository(database: services.database).current() }
    }

    @ViewBuilder
    private func section(_ entries: [TimeShiftEntry], title: String) -> some View {
        if !entries.isEmpty {
            Section(title) {
                ForEach(entries) { entry in
                    let cal = Calendar.current
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DayText.monthDayWeekday(entry.workDay, calendar: cal)).font(.headline)
                        Text("按\(DayText.monthDayWeekday(entry.restDay, calendar: cal))的课表上课")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .opacity(entry.isPast ? 0.6 : 1)
                }
            }
        }
    }
}
