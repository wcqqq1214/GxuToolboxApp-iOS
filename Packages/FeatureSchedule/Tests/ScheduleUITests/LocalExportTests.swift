import Foundation
import GxuAuth
import GxuFoundation
import GxuTestSupport
import ScheduleKit
import Testing
@testable import ScheduleUI

@MainActor
struct LocalExportTests {
    @Test func exportLoadsCacheAndAdjustmentsWithoutNetwork() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/profile/startDay", json: #"{"data":[{"year":2026,"term":1,"day":"2026-09-07","week":20}]}"#)
        backend.stub("GET /jw/schedule/personal", json: #"{"data":{"theoryList":[{"courseName":"数学","classId":"math-a","weeks":[1,2,3],"weekday":1,"sectionRange":"1-2","venueName":"旧教室"}]}}"#)
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "demo-a")
        let repo = ScheduleRepository(backend: backend, database: services.database)
        _ = try await repo.refreshStartDays()
        _ = try await repo.refreshSchedule(studentId: "demo-a", term: AcademicTerm(year: 2026, term: 1))
        let model = ScheduleViewModel()
        await model.load(services: services, cachedOnly: true)
        let source = try #require(model.index.occurrences.first)
        let request = try #require(model.manualAdjustmentRequest(for: source))
        try await model.saveManualAdjustments([
            ManualCourseAdjustment(sourceID: source.id, week: 4, weekday: 2, begin: 3, end: 4, location: "新教室")
        ], request: request)
        let offline = MockBackendAPI()
        let offlineServices = AppServices(backend: offline, database: services.database, shared: services.shared, accounts: services.accounts)
        let widgetKey = ScheduleKit.widgetSnapshotKey(studentId: "demo-a")
        let widget = NextCourses.empty(.missingSchedule, now: .distantPast)
        services.shared.set(widget, for: widgetKey)
        let exported = ScheduleViewModel()
        await exported.load(services: offlineServices, cachedOnly: true)
        #expect(exported.phase == .content)
        #expect(exported.index.occurrences.contains { $0.manualAdjustmentID != nil && $0.course.locationText == "新教室" })
        #expect(offline.calls.isEmpty)
        #expect(services.shared.value(widgetKey) == widget)
    }

    @Test func missingCacheShowsActionableMessageWithoutFetching() async {
        let backend = MockBackendAPI()
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations])
        let model = ScheduleViewModel()
        await model.load(services: services, cachedOnly: true)
        #expect(model.phase == .failed("本机还没有当前学期的课表，请先到个人课表同步后再导出"))
        #expect(backend.calls.isEmpty)
    }
}
