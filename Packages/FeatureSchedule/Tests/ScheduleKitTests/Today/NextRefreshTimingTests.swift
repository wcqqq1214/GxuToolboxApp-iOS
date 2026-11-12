import Foundation
import Testing
@testable import ScheduleKit

struct NextRefreshTimingTests {
    @Test func nextRefreshNotAfterNextStarts() {
        let s = Schedule(theoryList: [course("A", weekday: 1, 1, 2, weeks: [1]), course("B", weekday: 1, 5, 6, weeks: [1])])
        let r = NextCourseCalculator.compute(schedule: s, term: term, now: at("2026-09-07 07:00"))
        #expect(r.next?.name == "A")
        #expect(r.nextRefreshAt! <= r.next!.startsAt.addingTimeInterval(1))
        let during = NextCourseCalculator.compute(schedule: s, term: term, now: at("2026-09-07 08:30"))
        #expect(during.nextRefreshAt == at("2026-09-07 09:40").addingTimeInterval(1))
    }
}
