import Foundation
import GxuAuth
import GxuFoundation
import GxuTestSupport
import ScheduleKit
import Testing
@testable import ScheduleUI

@MainActor
struct ManualAdjustmentFlowTests {
    private func setup() async -> (ScheduleViewModel, AppServices) {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/profile/startDay", json: #"{"data":[{"year":2026,"term":1,"day":"2026-09-07","week":20}]}"#)
        backend.stub("GET /jw/schedule/personal", json: #"{"data":{"theoryList":[{"courseName":"数学","classId":"math-a","weeks":[1,2,3],"weekday":1,"sectionRange":"1-2","venueName":"旧教室"}]}}"#)
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "demo-a")
        let model = ScheduleViewModel(refreshCoordinator: ScheduleRefreshCoordinator(campusFetch: { _ in Data(#"{"holidays":[],"timeShift":[]}"#.utf8) }))
        await model.load(services: services)
        return (model, services)
    }

    @Test func editingAndRestoringUsesOriginalLessonAndSurvivesRefresh() async throws {
        let (model, services) = await setup()
        let source = try #require(model.index.occurrences.first)
        let request = try #require(model.manualAdjustmentRequest(for: source))
        let change = ManualCourseAdjustment(sourceID: source.id, week: 4, weekday: 2, begin: 3, end: 4, location: "新教室")
        try await model.saveManualAdjustments([change], request: request)
        #expect(model.selectedWeek == 4)
        #expect(model.index.occurrences.filter { $0.manualAdjustmentID != nil }.count == 1)
        await model.refresh(force: true)
        let moved = try #require(model.index.occurrences.first { $0.manualAdjustmentID != nil })
        #expect(moved.course.locationText == "新教室")
        let edited = try #require(model.manualAdjustmentRequest(for: moved))
        #expect(edited.source == source)
        #expect(edited.existing == change)
        let repo = ScheduleRepository(backend: services.backend, database: services.database)
        let snapshot = try #require(await repo.cachedSnapshot(studentId: "demo-a", now: source.date))
        #expect(snapshot.occurrences == model.index.occurrences)
        try await model.restoreManualAdjustment(edited)
        #expect(model.index.occurrences.contains(source))
        #expect(model.index.occurrences.allSatisfy { $0.manualAdjustmentID == nil })
        #expect(await repo.manualCourseAdjustments(studentId: "demo-a", term: request.term).isEmpty)
    }

    @Test func staleAccountRequestCannotWriteIntoNewAccount() async throws {
        let (model, services) = await setup()
        let source = try #require(model.index.occurrences.first)
        let request = try #require(model.manualAdjustmentRequest(for: source))
        let backend = try #require(services.backend as? MockBackendAPI)
        let other = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "demo-b")
        await model.load(services: other)
        let change = ManualCourseAdjustment(sourceID: source.id, week: 1, weekday: 2, begin: 1, end: 2, location: "新教室")
        await #expect(throws: GxuError.self) { try await model.saveManualAdjustments([change], request: request) }
        #expect(model.manualAdjustments.isEmpty)
        #expect(await ScheduleRepository(backend: other.backend, database: other.database).manualCourseAdjustments(studentId: "demo-b", term: request.term).isEmpty)
    }

    @Test func changedSourceIsRejectedAndShowsNoMisleadingAttendance() async throws {
        let (model, services) = await setup()
        let source = try #require(model.index.occurrences.first)
        let request = try #require(model.manualAdjustmentRequest(for: source))
        let change = ManualCourseAdjustment(sourceID: source.id, week: 1, weekday: 1, begin: 1, end: 2, location: "新教室")
        try await model.saveManualAdjustments([change], request: request)
        let moved = try #require(model.index.occurrences.first { $0.manualAdjustmentID != nil })
        let index = AttendanceIndex([AttendanceMark(date: "2026-09-07", periodRange: "1,2", statusCode: 1)], calendar: try #require(model.termCalendar).calendar)
        #expect(index.status(for: source) == .normal)
        #expect(index.status(for: moved) == nil)
        let backend = try #require(services.backend as? MockBackendAPI)
        backend.stub("GET /jw/schedule/personal", json: #"{"data":{"theoryList":[]}}"#)
        await model.refresh(force: true)
        await #expect(throws: GxuError.self) { try await model.saveManualAdjustments([change], request: request) }
    }

    @Test func batchAdjustAndSingleRestorePreservesOtherWeeks() async throws {
        let (model, services) = await setup()
        let original = model.index.occurrences
        let request = try #require(model.manualAdjustmentRequest(for: original[0]))
        let changes = request.related.filter { [1, 3].contains($0.week) }.map {
            ManualCourseAdjustment(sourceID: $0.id, week: $0.week, weekday: 5, begin: 9, end: 10, location: "临时教室")
        }
        try await model.saveManualAdjustments(changes, request: request)
        await model.refresh(force: true)
        #expect(model.index.occurrences.filter { $0.manualAdjustmentID != nil }.count == 2)
        let weekTwo = try #require(original.first { $0.week == 2 })
        #expect(model.index.occurrences.contains(weekTwo))
        let first = try #require(model.index.occurrences.first { $0.week == 1 })
        try await model.restoreManualAdjustment(try #require(model.manualAdjustmentRequest(for: first)))
        let reloaded = ScheduleViewModel(refreshCoordinator: ScheduleRefreshCoordinator(campusFetch: { _ in Data(#"{"holidays":[],"timeShift":[]}"#.utf8) }))
        await reloaded.load(services: services)
        #expect(reloaded.index.occurrences.filter { $0.manualAdjustmentID != nil }.map(\.week) == [3])
        #expect(reloaded.index.occurrences.contains(weekTwo))
        #expect(reloaded.index.occurrences.contains(original[0]))
    }

    @Test func staleTermRequestCannotRestoreCurrentTerm() async throws {
        let (model, services) = await setup()
        let source = try #require(model.index.occurrences.first)
        let request = try #require(model.manualAdjustmentRequest(for: source))
        let change = ManualCourseAdjustment(sourceID: source.id, week: 1, weekday: 3, begin: 3, end: 4, location: "调整教室")
        try await model.saveManualAdjustments([change], request: request)
        let backend = try #require(services.backend as? MockBackendAPI)
        backend.stub("GET /jw/profile/startDay", json: #"{"data":[{"year":2026,"term":1,"day":"2026-09-07","week":20},{"year":2025,"term":1,"day":"2025-09-01","week":20}]}"#)
        await model.refresh(force: true)
        await model.select(term: AcademicTerm(year: 2025, term: 1))
        #expect(model.term == AcademicTerm(year: 2025, term: 1))
        #expect(model.manualAdjustments.isEmpty)
        await #expect(throws: GxuError.self) { try await model.restoreManualAdjustment(request) }
        let repo = ScheduleRepository(backend: services.backend, database: services.database)
        #expect(await repo.manualCourseAdjustments(studentId: "demo-a", term: request.term) == [change])
    }

}
