import Foundation
import GxuAuth
import GxuFoundation
import GxuTestSupport
import ScheduleKit
import Testing
@testable import ScheduleUI

@MainActor
struct LocalExportAccountTests {
    @Test func changingAccountCannotExportPreviousCache() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/profile/startDay", json: #"{"data":[{"year":2026,"term":1,"day":"2026-09-07","week":20}]}"#)
        backend.stub("GET /jw/schedule/personal", json: #"{"data":{"theoryList":[{"courseName":"账号A的数学","classId":"math-a","weeks":[1,2,3],"weekday":1,"sectionRange":"1-2","venueName":"旧教室"}]}}"#)
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "demo-a")
        let repo = ScheduleRepository(backend: backend, database: services.database)
        _ = try await repo.refreshStartDays()
        _ = try await repo.refreshSchedule(studentId: "demo-a", term: AcademicTerm(year: 2026, term: 1))
        let model = ScheduleViewModel()
        await model.load(services: services, cachedOnly: true)
        #expect(model.phase == .content)
        let other = AppServices.preview(backend: MockBackendAPI(), features: [ScheduleKit.migrations], studentId: "demo-b")
        let switched = AppServices(backend: other.backend, database: services.database, shared: services.shared, accounts: other.accounts)
        await model.load(services: switched, cachedOnly: true)
        #expect(model.schedule == nil)
        #expect(model.index.occurrences.isEmpty)
        #expect(model.phase == .failed("本机还没有当前学期的课表，请先到个人课表同步后再导出"))
        #expect((other.backend as? MockBackendAPI)?.calls.isEmpty == true)
    }
}
