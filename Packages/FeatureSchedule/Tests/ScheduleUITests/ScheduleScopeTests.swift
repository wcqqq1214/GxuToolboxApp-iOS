import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
@testable import GxuStorage
import GxuTestSupport
import ScheduleKit
import Synchronization
import Testing
@testable import ScheduleUI

@MainActor
@Suite(.serialized)
struct ScheduleScopeTests {
    init() { URLProtocol.registerClass(StubURLProtocol.self) }
    func day(_ offset: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: offset, to: .now)!
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    func schedule(_ name: String) -> Schedule {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return Schedule(theoryList: [TheoryCourse(sectionRange: "1-2", begin: 1, end: 2, courseName: name, weeks: Array(1...20), weekday: weekday == 1 ? 7 : weekday - 1)])
    }
    func seed(_ backend: MockBackendAPI, days: [TermStartDay], name: String) throws {
        backend.stub("GET /jw/profile/startDay", json: try JSONEncoder().encode(["data": days]))
        backend.stub("GET /jw/schedule/personal", json: try JSONEncoder().encode(["data": schedule(name)]))
    }
    @Test func rolloverFailureMustNotRelabelOldSchedule() async throws {
        let old = TermStartDay(year: 2025, term: 1, day: day(-400), week: 20)
        let new = TermStartDay(year: 2026, term: 1, day: day(-10), week: 20)
        let backend = MockBackendAPI()
        try seed(backend, days: [old], name: "OLD-TERM-COURSE")
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "A")
        let repository = ScheduleRepository(backend: backend, database: services.database)
        try await repository.refreshStartDays()
        try await repository.refreshSchedule(studentId: "A", term: old.academicTerm)
        let model = ScheduleViewModel()
        await model.load(services: services)
        #expect(model.term == old.academicTerm)
        backend.stub("GET /jw/profile/startDay", json: try JSONEncoder().encode(["data": [old, new]]))
        backend.stub("GET /jw/schedule/personal", error: .network("offline"))
        await model.refresh()
        await model.save(CustomActivity(id: "new", name: "NEW-TERM-ACTIVITY", weekFrom: 1, weekTo: 20))
        #expect(model.term == old.academicTerm)
        #expect(model.schedule?.theoryList.map(\.courseName) == ["OLD-TERM-COURSE"])
        #expect(model.refreshError != nil)
        #expect(await repository.customActivities(studentId: "A", term: old.academicTerm).map(\.id) == ["new"])
        #expect(await repository.customActivities(studentId: "A", term: new.academicTerm).isEmpty)
    }
    @Test func saveCompletingAfterAccountSwitchMustNotLeakActivity() async throws {
        let current = TermStartDay(year: 2026, term: 1, day: day(-10), week: 20)
        let backend = MockBackendAPI()
        try seed(backend, days: [current], name: "A-COURSE")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appending(path: "schedule.sqlite").path
        let db = try AppDatabase(writer: DatabasePool(path: path), features: [ScheduleKit.migrations])
        let a = AppServices.preview(backend: backend, studentId: "A")
        let b = AppServices.preview(backend: backend, studentId: "B")
        let shared = InMemorySharedStore()
        let svcA = AppServices(backend: backend, database: db, shared: shared, accounts: a.accounts)
        let svcB = AppServices(backend: backend, database: db, shared: shared, accounts: b.accounts)
        let repository = ScheduleRepository(backend: backend, database: db)
        try await repository.refreshStartDays()
        try seed(backend, days: [current], name: "B-COURSE")
        try await repository.refreshSchedule(studentId: "B", term: current.academicTerm)
        try seed(backend, days: [current], name: "A-COURSE")
        let model = ScheduleViewModel()
        await model.load(services: svcA)
        let (entries, entered) = AsyncStream<Void>.makeStream()
        let release = DispatchSemaphore(value: 0)
        let blocker = Task.detached {
            try await db.writer.write { _ in
                entered.yield(())
                _ = release.wait(timeout: .now() + 5)
            }
        }
        var entry = entries.makeAsyncIterator()
        _ = await entry.next()
        defer { release.signal() }
        let weekday = Calendar.current.component(.weekday, from: .now)
        let activity = CustomActivity(id: "A-private", name: "A-PRIVATE-LAB", weekday: weekday == 1 ? 7 : weekday - 1, begin: 11, end: 12, weekFrom: 1, weekTo: 20)
        let (starts, started) = AsyncStream<Void>.makeStream()
        let save = Task {
            started.yield(())
            await model.save(activity)
        }
        var start = starts.makeAsyncIterator()
        _ = await start.next()
        backend.stub("GET /jw/profile/startDay", error: .network("offline"))
        await model.load(services: svcB)
        #expect(model.schedule?.theoryList.map(\.courseName) == ["B-COURSE"])
        #expect(model.activities.isEmpty)
        release.signal()
        try await blocker.value
        await save.value
        let storedB = await repository.customActivities(studentId: "B", term: current.academicTerm)
        let storedA = await repository.customActivities(studentId: "A", term: current.academicTerm)
        #expect(storedB.isEmpty)
        #expect(storedA.map(\.name) == ["A-PRIVATE-LAB"])
        #expect(model.activities.isEmpty)
        #expect(!model.index.occurrences.contains(where: { $0.course.courseName == "A-PRIVATE-LAB" }))
    }

    @Test func customActivityChangesNotifyAfterPublishingTheNewSchedule() async throws {
        let weekdayOffset = (Calendar.current.component(.weekday, from: .now) + 5) % 7
        let term = TermStartDay(year: 2026, term: 1, day: day(-7 - weekdayOffset), week: 20)
        let backend = MockBackendAPI()
        try seed(backend, days: [term], name: "BASE")
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "A")
        let fetchCalendar: CampusCalendarRepository.Fetch = { _ in Data(#"{"holidays":[],"timeShift":[]}"#.utf8) }
        try await CampusCalendarRepository(database: services.database, fetch: fetchCalendar).refresh()
        let model = ScheduleViewModel(refreshCoordinator: ScheduleRefreshCoordinator(campusFetch: fetchCalendar))
        await model.load(services: services)
        let key = ScheduleKit.widgetSnapshotKey(studentId: "A")
        var published: [[String]] = []
        model.onCustomActivitiesChanged = { services in
            let snapshot = services.shared.value(key)
            published.append(snapshot?.tomorrow.map(\.name) ?? [])
        }

        let calendar = try #require(model.termCalendar)
        let tomorrow = try #require(calendar.calendar.date(byAdding: .day, value: 1, to: .now))
        let week = calendar.week(containing: tomorrow)
        var activity = CustomActivity(id: "lab", name: "实验", weekday: calendar.weekday(of: tomorrow), begin: 5, end: 6, weeks: [week])
        await model.save(activity)
        activity.name = "实验改名"
        await model.save(activity)
        await model.delete(activity)

        #expect(published.count == 3)
        #expect(published.first?.contains("实验") == true)
        #expect(published.dropFirst().first?.contains("实验改名") == true)
        #expect(published.last?.contains("实验改名") == false)
    }

    @Test func historicalTermMustNotReplaceCurrentWidget() async throws {
        let cal = Calendar.current
        let weekday = (cal.component(.weekday, from: .now) + 5) % 7 + 1
        let monday = cal.date(byAdding: .day, value: -(weekday - 1) - 7, to: .now)!
        func day(_ date: Date) -> String {
            let c = cal.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
        }
        let current = TermStartDay(year: 2026, term: 1, day: day(monday), week: 20)
        let old = TermStartDay(year: 2025, term: 1, day: day(cal.date(byAdding: .day, value: -420, to: monday)!), week: 20)
        let backend = MockBackendAPI()
        backend.stub("GET /jw/profile/startDay", json: try JSONEncoder().encode(["data": [old, current]]))
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "A")
        let repo = ScheduleRepository(backend: backend, database: services.database)
        try await repo.refreshStartDays()
        for (term, name) in [(old, "HISTORICAL"), (current, "CURRENT")] {
            let courses = (1...7).map { TheoryCourse(courseName: name, weeks: Array(1...20), weekday: $0) }
            backend.stub("GET /jw/schedule/personal", json: try JSONEncoder().encode(["data": Schedule(theoryList: courses)]))
            try await repo.refreshSchedule(studentId: "A", term: term.academicTerm)
        }
        backend.stub("GET /jw/profile/startDay", error: .network("offline fixture"))
        let model = ScheduleViewModel()
        await model.load(services: services)
        let key = ScheduleKit.widgetSnapshotKey(studentId: "A")
        let before = try #require(services.shared.value(key))
        #expect(before.next?.name == "CURRENT")
        await model.select(term: old.academicTerm)
        let after = try #require(services.shared.value(key))
        #expect(after == before)
    }

    @Test func attendanceCacheWriteSupersedesAnInFlightRead() async throws {
        let term = TermStartDay(year: 2026, term: 1, day: day(-7), week: 20)
        let backend = MockBackendAPI()
        try seed(backend, days: [term], name: "COURSE")
        let services = AppServices.preview(backend: backend, features: [ScheduleKit.migrations], studentId: "A")
        let model = ScheduleViewModel()
        await model.load(services: services)
        let occurrence = try #require(model.index.occurrences.first)
        let formatter = DateFormatter()
        formatter.calendar = try #require(model.termCalendar?.calendar)
        formatter.timeZone = formatter.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: occurrence.date)
        let old = AttendanceMark(date: date, periodRange: "1,2", statusCode: 2)
        let fresh = AttendanceMark(date: date, periodRange: "1,2", statusCode: 1)
        let (entered, didEnter) = AsyncStream<Void>.makeStream()
        let (release, finishRead) = AsyncStream<Void>.makeStream()
        let calls = Mutex(0)
        model.layersProvider = { _, _ in
            let first = calls.withLock { count in
                count += 1
                return count == 1
            }
            if first {
                didEnter.yield(())
                for await _ in release { break }
                return ScheduleExtraLayers(attendance: [old])
            }
            return ScheduleExtraLayers(attendance: [fresh])
        }
        let reading = Task { await model.refreshExamLayer() }
        var firstRead = entered.makeAsyncIterator()
        _ = await firstRead.next()
        await model.refreshExamLayer(afterCacheWrite: true)
        finishRead.finish()
        await reading.value
        #expect(model.attendance?.status(for: occurrence) == .normal)
    }
}
