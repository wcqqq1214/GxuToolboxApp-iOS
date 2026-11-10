import Foundation
import GxuFoundation
import GxuNetworking
import GxuAuth
import GxuTestSupport
import ScheduleKit
import Testing
@testable import FeatureCampus

private let shanghai: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return calendar
}()

private func at(_ text: String) -> Date {
    let f = DateFormatter()
    f.calendar = shanghai
    f.timeZone = shanghai.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: text)!
}

private func fixture(_ name: String) throws -> Data { try loadFixture(name, bundle: .module) }

struct CampusTests {
    let term = AcademicTerm(year: 2025, term: 1)

    @Test func apiDecodesRealResponses() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/schedule/schools", json: try fixture("campus-schools"))
        backend.stub("GET /jw/schedule/majors", json: try fixture("campus-majors"))
        backend.stub("GET /jw/schedule/class-schedules", json: try fixture("campus-classes"))
        let api = CampusAPI(backend: backend)

        let schools = try await api.schools()
        #expect(schools.count == 5 && schools[0].id.isEmpty == false)
        let majors = try await api.majors(grade: "2022", school: schools[0].id)
        #expect(majors.count == 4)
        let classes = try await api.classes(term: term, school: "30300", grade: "2022")
        #expect(classes.count == 4)
        #expect(classes[0].schoolId == "30300" && !classes[0].classId.isEmpty && !classes[0].className.isEmpty)
    }

    @Test func emptyFiltersAreNotSent() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/schedule/majors", json: try fixture("campus-majors"))
        mock.stub("GET /jw/schedule/class-schedules", json: try fixture("campus-classes"))
        let backend = RecordingBackend(mock)
        let api = CampusAPI(backend: backend)
        _ = try await api.majors(grade: "", school: "30300")
        _ = try await api.classes(term: term, school: "30300")
        let queries = backend.queries
        #expect(queries[0] == ["school": "30300"])
        #expect(queries[1] == ["school": "30300", "year": "2025", "term": "1"])
    }

    @Test func scheduleDecodesAndNullIsAnError() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /jw/schedule/class-schedule", json: try fixture("campus-class-schedule"))
        let backend = RecordingBackend(mock)
        let info = ClassInfo.sample
        let schedule = try await CampusAPI(backend: backend).schedule(term: term, of: info)
        #expect(schedule.theoryList.count == 3)
        #expect(backend.queries[0]["classid"] == info.classId && backend.queries[0]["major"] == info.majorId)

        let nullBackend = MockBackendAPI()
        nullBackend.stub("GET /jw/schedule/class-schedule", json: Data(#"{"code":200,"message":"success","data":null}"#.utf8))
        await #expect(throws: GxuError.self) { try await CampusAPI(backend: nullBackend).schedule(term: term, of: info) }
    }

    @Test func unsupportedTermIsRejectedWithoutRequest() async {
        let backend = RecordingBackend(MockBackendAPI())
        await #expect(throws: GxuError.self) { try await CampusAPI(backend: backend).classes(term: AcademicTerm(year: 2025, term: 3), school: "x") }
        #expect(backend.queries.isEmpty)
    }

    // MARK: 此刻有没有课

    @Test func occupancyMatchesWeekWeekdayAndPeriod() throws {
        let schedule = try JSONDecoder().decode(DataEnvelope<Schedule>.self, from: try fixture("campus-class-schedule")).data
        let first = try #require(schedule.theoryList.first)   // 周一 1-2 节，1-4、6-8 周
        let hit = ClassMoment(week: 1, weekday: first.weekday, period: first.begin)
        #expect(Occupancy.course(in: schedule, at: hit)?.courseName == first.courseName)
        #expect(Occupancy.course(in: schedule, at: ClassMoment(week: 1, weekday: first.weekday, period: first.end))?.courseName == first.courseName)
        #expect(Occupancy.course(in: schedule, at: ClassMoment(week: 5, weekday: first.weekday, period: first.begin)) == nil)   // 第 5 周没课
        #expect(Occupancy.course(in: schedule, at: ClassMoment(week: 1, weekday: 7, period: 1)) == nil)
        #expect(Occupancy.course(in: schedule, at: ClassMoment(week: 1, weekday: first.weekday, period: 13)) == nil)
    }

    @Test func defaultMomentFollowsTheClock() {
        // 2026-09-07（周一）开学
        let term = TermCalendar(startDate: at("2026-09-07 00:00"), weekCount: 18, calendar: shanghai)
        #expect(ClassMoment.now(term: term, now: at("2026-09-08 08:30")) == ClassMoment(week: 1, weekday: 2, period: 1))
        #expect(ClassMoment.now(term: term, now: at("2026-09-08 09:45")) == ClassMoment(week: 1, weekday: 2, period: 3))   // 课间取下一节
        #expect(ClassMoment.now(term: term, now: at("2026-09-08 06:00")).period == 1)
        #expect(ClassMoment.now(term: term, now: at("2026-09-08 23:30")).period == 13)
        #expect(ClassMoment.now(term: term, now: at("2026-09-02 10:00")).week == 1)    // 开学前夹到第 1 周
        #expect(ClassMoment.now(term: term, now: at("2027-03-01 10:00")).week == 18)   // 学期后夹到最后一周
    }
}

private struct DataEnvelope<T: Decodable & Sendable>: Decodable, Sendable { let data: T }

extension ClassInfo {
    static var sample: ClassInfo {
        try! JSONDecoder().decode(ClassInfo.self, from: Data(#"{"schoolId":"30300","majorId":"0311","grade":"2022","classId":"C1","className":"示例班"}"#.utf8))
    }
}

/// 转发给 Mock，同时记下每次请求的 query（`MockBackendAPI.calls` 只有路径）
private final class RecordingBackend: BackendAPI, @unchecked Sendable {
    private let wrapped: MockBackendAPI
    private let lock = NSLock()
    private var recorded: [[String: String]] = []

    init(_ wrapped: MockBackendAPI) { self.wrapped = wrapped }

    var queries: [[String: String]] { lock.withLock { recorded } }

    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        lock.withLock { recorded.append(query) }
        return try await wrapped.get(path, query: query, auth: auth, as: type)
    }

    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        try await wrapped.post(path, body: body, auth: auth, as: type)
    }
}
