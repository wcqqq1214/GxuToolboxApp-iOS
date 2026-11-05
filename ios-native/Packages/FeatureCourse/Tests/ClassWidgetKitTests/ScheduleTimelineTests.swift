import Foundation
import ScheduleKit
import Testing
@testable import ClassWidgetKit

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return c
}()

private func at(_ s: String) -> Date {
    let f = DateFormatter()
    f.calendar = cal; f.timeZone = cal.timeZone; f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}

private func course(_ name: String, _ day: String, _ start: String, _ end: String, room: String = "A101") -> WidgetCourse {
    WidgetCourse.make(name: name, room: room, startsAt: at("\(day) \(start)"), endsAt: at("\(day) \(end)"), calendar: cal)
}

private func snapshot(now: String, today: [WidgetCourse], tomorrow: [WidgetCourse] = [], next: WidgetCourse? = nil) -> NextCourses {
    NextCourses.make(today: today, tomorrow: tomorrow, next: next, refreshedAt: at(now))
}

@Suite struct ScheduleTimelineTests {
    let math = course("高等数学", "2026-11-05", "08:00", "09:40")
    let phys = course("大学物理", "2026-11-05", "10:00", "11:40")
    let net = course("计算机网络", "2026-11-05", "14:30", "16:05")
    let tmr = course("英语", "2026-11-06", "08:00", "09:40")

    @Test func beforeFirstClass() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math, phys, net], tomorrow: [tmr])
        let e = ScheduleTimeline.entry(at: at("2026-11-05 07:00"), snapshot: snap, calendar: cal)
        #expect(e.phase == .waiting)
        #expect(e.current == nil)
        #expect(e.upcoming.map(\.name) == ["高等数学", "大学物理", "计算机网络"])
        #expect(e.focus?.name == "高等数学")
        #expect(e.tomorrow.map(\.name) == ["英语"])
    }

    @Test func inClassAndBoundaries() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math, phys, net], tomorrow: [tmr])
        // 开始时刻算上课中；结束时刻算已下课
        #expect(ScheduleTimeline.entry(at: at("2026-11-05 08:00"), snapshot: snap, calendar: cal).current?.name == "高等数学")
        let atEnd = ScheduleTimeline.entry(at: at("2026-11-05 09:40"), snapshot: snap, calendar: cal)
        #expect(atEnd.current == nil)
        #expect(atEnd.phase == .waiting)
        let mid = ScheduleTimeline.entry(at: at("2026-11-05 10:30"), snapshot: snap, calendar: cal)
        #expect(mid.phase == .inClass)
        #expect(mid.upcoming.map(\.name) == ["计算机网络"])
        #expect(mid.focus?.name == "大学物理")
    }

    @Test func finishedToday() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math, phys, net], tomorrow: [tmr])
        let e = ScheduleTimeline.entry(at: at("2026-11-05 17:00"), snapshot: snap, calendar: cal)
        #expect(e.phase == .finished)
        #expect(e.hadClassesToday)
        #expect(e.next?.name == "英语")
        #expect(e.tomorrow.map(\.name) == ["英语"])
    }

    @Test func nothingTodayShowsNext() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [], tomorrow: [], next: course("线性代数", "2026-11-09", "08:00", "09:40"))
        let e = ScheduleTimeline.entry(at: at("2026-11-05 12:00"), snapshot: snap, calendar: cal)
        #expect(e.phase == .finished)
        #expect(!e.hadClassesToday)
        #expect(e.next?.name == "线性代数")
    }

    @Test func midnightRollsToTomorrowList() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math], tomorrow: [tmr])
        let e = ScheduleTimeline.entry(at: at("2026-11-06 00:00"), snapshot: snap, calendar: cal)
        #expect(e.phase == .waiting)
        #expect(e.upcoming.map(\.name) == ["英语"])
    }

    @Test func staleWhenBeyondCoverage() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math], tomorrow: [tmr])
        let e = ScheduleTimeline.entry(at: at("2026-11-07 09:00"), snapshot: snap, calendar: cal)
        #expect(e.phase == .stale)
        #expect(e.upcoming.isEmpty)
    }

    @Test func unavailableStates() {
        let snap = NextCourses.empty(.missingSchedule, now: at("2026-11-05 07:00"))
        #expect(ScheduleTimeline.entry(at: at("2026-11-05 07:00"), snapshot: snap, calendar: cal).phase == .unavailable(.missingSchedule))
    }

    @Test func timelineHasEntryAtEveryStartAndEnd() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math, phys, net], tomorrow: [tmr])
        let (entries, reload) = ScheduleTimeline.entries(snapshot: snap, now: at("2026-11-05 07:00"), calendar: cal)
        let dates = Set(entries.map(\.date))
        for c in [math, phys, net, tmr] {
            #expect(dates.contains(c.startsAt))
            #expect(dates.contains(c.endsAt))
        }
        #expect(dates.contains(at("2026-11-06 00:00")))
        #expect(entries.first?.date == at("2026-11-05 07:00"))
        #expect(entries.map(\.date) == entries.map(\.date).sorted())
        #expect(reload == entries.last?.date)
    }

    @Test func timelineSkipsPastBoundaries() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math, phys, net], tomorrow: [tmr])
        let (entries, _) = ScheduleTimeline.entries(snapshot: snap, now: at("2026-11-05 10:30"), calendar: cal)
        #expect(entries.allSatisfy { $0.date >= at("2026-11-05 10:30") })
        #expect(entries.first?.current?.name == "大学物理")
    }
}

@Suite struct ClassActivityPlanTests {
    let math = course("高等数学", "2026-11-05", "08:00", "09:40")
    let phys = course("大学物理", "2026-11-05", "10:00", "11:40")

    @Test func currentClassWins() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math, phys])
        let plan = ClassActivityPlan.make(snapshot: snap, now: at("2026-11-05 08:30"), calendar: cal)
        #expect(plan?.state.name == "高等数学")
        #expect(plan?.staleDate == math.endsAt)
        #expect(plan?.state.followingName == "大学物理")
    }

    @Test func startsWithinLeadTime() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math, phys])
        let plan = ClassActivityPlan.make(snapshot: snap, now: at("2026-11-05 07:15"), calendar: cal)
        #expect(plan?.state.name == "高等数学")
        #expect(plan?.staleDate == math.startsAt)
    }

    @Test func tooEarlyHasNoActivity() {
        let snap = snapshot(now: "2026-11-05 05:00", today: [math, phys])
        #expect(ClassActivityPlan.make(snapshot: snap, now: at("2026-11-05 06:30"), calendar: cal) == nil)
    }

    @Test func betweenClassesPicksUpcomingWithinLead() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math, phys])
        let plan = ClassActivityPlan.make(snapshot: snap, now: at("2026-11-05 09:45"), calendar: cal)
        #expect(plan?.state.name == "大学物理")
        #expect(plan?.state.followingName == nil)
    }

    @Test func afterLastClassHasNoActivity() {
        let snap = snapshot(now: "2026-11-05 07:00", today: [math, phys])
        #expect(ClassActivityPlan.make(snapshot: snap, now: at("2026-11-05 12:00"), calendar: cal) == nil)
    }

    @Test func unavailableSnapshotHasNoActivity() {
        #expect(ClassActivityPlan.make(snapshot: .empty(.missingSchedule, now: at("2026-11-05 07:00")), now: at("2026-11-05 07:00")) == nil)
    }
}

@Suite struct IntentTextTests {
    @Test func describeEmpty() {
        #expect(ScheduleQuery.describe(dayName: "今天", courses: []) == "今天没有课。")
    }

    @Test func describeList() {
        let a = course("高等数学", "2026-11-05", "08:00", "09:40", room: "西3-406")
        let b = course("英语", "2026-11-05", "10:00", "11:40", room: "")
        #expect(ScheduleQuery.describe(dayName: "今天", courses: [a, b]) == "今天有 2 节课：08:00 高等数学（西3-406）；10:00 英语。")
    }

    @Test func coursesOnDayFiltersByDate() {
        // 第 1 周周一 = 2026-11-02
        let term = TermCalendar(startDate: at("2026-11-02 00:00"), weekCount: 18, calendar: cal)
        let schedule = Schedule(theoryList: [
            TheoryCourse(venueName: "A1", sectionRange: "1-2", begin: 1, end: 2, courseName: "周一课", weeks: [1, 2], weekday: 1),
            TheoryCourse(venueName: "A2", sectionRange: "3-4", begin: 3, end: 4, courseName: "周二课", weeks: [1], weekday: 2),
        ])
        #expect(ScheduleQuery.courses(on: at("2026-11-02 12:00"), schedule: schedule, term: term).map(\.name) == ["周一课"])
        #expect(ScheduleQuery.courses(on: at("2026-11-03 12:00"), schedule: schedule, term: term).map(\.name) == ["周二课"])
        #expect(ScheduleQuery.courses(on: at("2026-11-09 12:00"), schedule: schedule, term: term).map(\.name) == ["周一课"])
        #expect(ScheduleQuery.courses(on: at("2026-11-10 12:00"), schedule: schedule, term: term).isEmpty)
    }
}
