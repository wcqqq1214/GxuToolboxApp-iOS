import Foundation
import GxuFoundation
import GxuStorage
import GxuTestSupport
import Testing
@testable import ScheduleKit

struct ColorTests {
    @Test func adjacentCoursesGetDifferentColors() {
        let courses = [course("A", 1, 2), course("B", 3, 4), course("C", 5, 6), course("D", weekday: 2, 1, 2)]
        let colors = CourseColorAssigner.assign(courses: courses)
        #expect(colors.count == 4)
        #expect(colors["A"] != colors["B"] && colors["B"] != colors["C"])
        #expect(Set(colors.values).count == 4)   // 色盘够用时每门课都不同
    }

    @Test func assignmentIsStableAndHonorsCustomColors() {
        let courses = (0..<8).map { course("课\($0)", weekday: $0 % 5 + 1, $0 % 4 * 2 + 1, $0 % 4 * 2 + 2) }
        #expect(CourseColorAssigner.assign(courses: courses) == CourseColorAssigner.assign(courses: courses.reversed()))
        let custom = CourseColorAssigner.assign(courses: courses, custom: ["课3": 0x123456])
        #expect(custom["课3"] == 0x123456)
    }

    @Test func manyCoursesStillColored() {
        let courses = (0..<40).map { course("课\($0)", weekday: 1, 1, 2) }   // 全部相邻且超过色盘
        let colors = CourseColorAssigner.assign(courses: courses)
        #expect(colors.count == 40)
    }

    @Test func hashMatchesJavaScriptImplementation() {
        // RN: hash = c + ((hash << 5) - hash)，32 位
        #expect(CourseColorAssigner.hash("") == 0)
        #expect(CourseColorAssigner.hash("a") == 97)
        #expect(CourseColorAssigner.hash("ab") == 97 * 31 + 98)
    }
}

@MainActor
struct RepositoryTests {
    private func makeRepository(_ backend: MockBackendAPI) throws -> ScheduleRepository {
        ScheduleRepository(backend: backend, database: try .inMemory(features: [ScheduleKit.migrations]))
    }

    private let autumn = AcademicTerm(year: 2026, term: 1)

    @Test func refreshCachesPerStudent() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/schedule/personal", json: try loadFixture("personal", bundle: .module))
        let repo = try makeRepository(backend)

        #expect(try await repo.cachedSchedule(studentId: "A", term: autumn) == nil)
        let fresh = try await repo.refreshSchedule(studentId: "A", term: autumn, now: Date(timeIntervalSince1970: 1000))
        let cached = try #require(try await repo.cachedSchedule(studentId: "A", term: autumn))
        #expect(cached == fresh)
        #expect(cached.schedule.theoryList.count == 5)
        #expect(cached.updatedAt == Date(timeIntervalSince1970: 1000))
        // 其它账号、其它学期读不到
        #expect(try await repo.cachedSchedule(studentId: "B", term: autumn) == nil)
        #expect(try await repo.cachedSchedule(studentId: "A", term: AcademicTerm(year: 2026, term: 2)) == nil)
    }

    @Test func nullResponseKeepsOldCache() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/schedule/personal", json: try loadFixture("personal", bundle: .module))
        let repo = try makeRepository(backend)
        try await repo.refreshSchedule(studentId: "A", term: autumn)

        backend.stub("GET /jw/schedule/personal", json: #"{"data": null}"#)
        await #expect(throws: GxuError.self) { try await repo.refreshSchedule(studentId: "A", term: autumn) }
        #expect(try await repo.cachedSchedule(studentId: "A", term: autumn)?.schedule.theoryList.count == 5)

        backend.stub("GET /jw/schedule/personal", error: .sessionExpired(.jw))
        await #expect(throws: GxuError.sessionExpired(.jw)) { try await repo.refreshSchedule(studentId: "A", term: autumn) }
    }

    @Test func startDaysUpsert() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/profile/startDay", json: """
        {"data": [{"year": 2026, "term": 1, "day": "2026-09-07", "week": 18, "is_current": true},
                  {"year": "2027", "term": 2, "day": "2027-03-01T00:00:00.000Z", "week": 18, "is_current": false}]}
        """)
        let repo = try makeRepository(backend)
        let remote = try await repo.refreshStartDays()
        #expect(remote.count == 2 && remote[1].year == 2027)
        #expect(try await repo.cachedStartDays().map(\.day) == ["2026-09-07", "2027-03-01T00:00:00.000Z"])

        backend.stub("GET /jw/profile/startDay", json: #"{"data": [{"year": 2026, "term": 1, "day": "2026-09-14", "week": 17}]}"#)
        try await repo.refreshStartDays()
        let cached = try await repo.cachedStartDays()
        #expect(cached.count == 2 && cached[0].day == "2026-09-14" && cached[0].week == 17)

        backend.stub("GET /jw/profile/startDay", json: #"{"data": []}"#)
        #expect(try await repo.refreshStartDays().count == 2)   // 空响应不清缓存
    }

    @Test func currentTermInfoUsesCacheThenRefreshes() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/profile/startDay", json: """
        {"data": [{"year": 2026, "term": 1, "day": "2026-09-07T00:00:00.000Z", "week": 18}]}
        """)
        let repo = try makeRepository(backend)

        // 没有缓存：联网刷新
        let before = try #require(await repo.currentTermInfo(now: at("2026-08-30"), calendar: shanghai))
        #expect(before.term == AcademicTerm(year: 2026, term: 1) && before.isStarted == false && before.isEnded == false)
        #expect(backend.calls == ["GET /jw/profile/startDay"])

        // 有缓存且学期未结束：不再联网
        let during = try #require(await repo.currentTermInfo(now: at("2026-10-01"), calendar: shanghai))
        #expect(during.isStarted && !during.isEnded)
        #expect(backend.calls.count == 1)

        // 学期结束：尝试刷新；刷新失败仍用缓存，标记已结束
        backend.stub("GET /jw/profile/startDay", error: .network("offline"))
        let after = try #require(await repo.currentTermInfo(now: at("2027-03-01"), calendar: shanghai))
        #expect(after.isEnded)
        #expect(backend.calls.count == 2)
    }

    @Test func currentTermInfoIsNilWithoutAnyData() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/profile/startDay", error: .network("offline"))
        #expect(await (try makeRepository(backend)).currentTermInfo() == nil)
    }
}
