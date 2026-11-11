import Foundation
import GxuAuth
import GxuTestSupport
import ScheduleKit
import Testing
@testable import ScheduleUI

@MainActor
struct RescheduleBadgeTests {
    @Test func onlyAdjustedLessonAnnouncesReschedule() async throws {
        let backend = MockBackendAPI()
        let reschedulesPath = "/jw/schedule/personal/reschedules"
        backend.stub("GET /jw/profile/startDay", json: #"{"data":[{"year":2026,"term":1,"day":"2026-09-07","week":20}]}"#)
        backend.stub("GET /jw/schedule/personal", json: """
        {"data":{"theoryList":[
            {"courseName":"数学","classId":"class-a","isRescheduled":true,"weeks":[1,2,3],"weekday":2,"sectionRange":"3-4"},
            {"courseName":"数学","classId":"class-a","isRescheduled":true,"weeks":[2],"weekday":2,"sectionRange":"5-6"},
            {"courseName":"数学","classId":"class-a","isRescheduled":true,"weeks":[2],"weekday":1,"sectionRange":"3-4"},
            {"courseName":"数学","classId":"class-b","weeks":[2],"weekday":2,"sectionRange":"3-4"}
        ]}}
        """)
        backend.stub("GET \(reschedulesPath)", json: """
        {"data":[{"before":{"weeks":"2","weekday":"一","sections":"3-4"},
                   "after":{"weeks":"2","weekday":"二","sections":"3-4"}}]}
        """)
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "demo")
        let model = ScheduleViewModel(refreshCoordinator: ScheduleRefreshCoordinator(
            campusFetch: { _ in Data(#"{"holidays":[],"timeShift":[]}"#.utf8) }
        ))
        await model.load(services: services)
        let request = try #require(model.rescheduleRequest)
        await model.loadRescheduleBadges(for: request)
        #expect(backend.getRequests.filter { $0.path == reschedulesPath }.map(\.query) == [["classId": "class-a"]])

        let occurrences = model.index.occurrences
        #expect(occurrences.count == 6)
        let announced = occurrences.filter { occurrence in
            CourseBlock(group: ScheduleExpander.conflictGroups([occurrence])[0], selected: occurrence,
                        colors: [:], rowHeight: 64, showsRescheduleBadge: model.showsRescheduleBadge(for: occurrence))
                .accessibilityText.contains("已调课")
        }
        let adjusted = try #require(announced.first)
        #expect(announced.count == 1)
        #expect(adjusted.course.classId == "class-a")
        #expect(adjusted.week == 2)
        #expect(adjusted.weekday == 2)
        #expect(adjusted.begin == 3 && adjusted.end == 4)

        backend.stub("GET \(reschedulesPath)", error: .network("offline"))
        await model.loadRescheduleBadges(for: request)
        #expect(model.showsRescheduleBadge(for: adjusted))

        backend.stub("GET \(reschedulesPath)", json: #"{"data":[]}"#)
        await model.loadRescheduleBadges(for: request)
        #expect(!model.showsRescheduleBadge(for: adjusted))
    }
}
