import GxuAuth
import GxuDesign
import ScheduleKit
import SwiftUI

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
