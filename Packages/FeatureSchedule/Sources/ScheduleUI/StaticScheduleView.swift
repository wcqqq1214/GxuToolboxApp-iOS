import GxuAuth
import GxuDesign
import ScheduleKit
import SwiftUI

/// 只读课表：给定一份课表和学期周历（别人的班级课表等），用和个人课表一样的周网格显示。
/// 不含日程、冲突选择和刷新；节假日 / 补班会叠加。标题、导航栏由外层提供。
public struct StaticScheduleView: View {
    private let schedule: Schedule
    private let termCalendar: TermCalendar
    @Environment(\.services) private var services
    @Environment(SchedulePreferencesStore.self) private var preferences
    @State private var model = ScheduleViewModel()
    @State private var detail: ConflictGroup?

    public init(schedule: Schedule, termCalendar: TermCalendar) {
        self.schedule = schedule
        self.termCalendar = termCalendar
    }

    public var body: some View {
        Group {
            if model.phase == .content {
                ScheduleBoard(model: model) { detail = $0 }
            } else {
                GxuLoadingView("正在加载课表…")
            }
        }
        .task(id: preferences.value.palette) {
            model.palette = preferences.value.palette
            let campus = await CampusCalendarRepository(database: services.database).current()
            model.loadStatic(schedule: schedule, termCalendar: termCalendar, campus: campus)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if model.phase == .content { ScheduleWeekTitle(model: model) }
            }
        }
        .sheet(item: $detail) { group in
            CourseDetailSheet(group: group, colors: model.colors, selected: group.items[0], onChoose: { _ in }, onEditActivity: { _ in })
        }
    }
}
