import Foundation
import GxuFoundation
import GxuTestSupport
import Testing
@testable import FeatureMisc

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return c
}()

@Suite struct AttendanceDecodingTests {
    @Test func envelopeCode600Unwraps() throws {
        let env = try decode(AttendanceEnvelope<AttendanceMenu>.self, #"{"code":600,"msg":"","data":{"calendarList":[{"calendarId":18,"calendarName":"2025-1","firstWeekBegin":"2025-09-01 00:00:00","lastWeekEnd":"2026-01-18","weekTotal":20,"isCurrent":1}]}}"#)
        let menu = try env.unwrap()
        #expect(menu.calendarList.count == 1)
        #expect(menu.calendarList[0].isCurrent)
        #expect(menu.calendarList[0].calendarId == 18)
    }

    @Test func envelopeOtherCodeThrowsServerMessage() throws {
        let env = try decode(AttendanceEnvelope<AttendanceMenu>.self, #"{"code":401,"msg":"登录已失效","data":null}"#)
        #expect(throws: GxuError.invalidData("登录已失效")) { try env.unwrap() }
        let noMsg = try decode(AttendanceEnvelope<AttendanceMenu>.self, #"{"code":500}"#)
        #expect(throws: GxuError.invalidData("考勤系统返回了错误（500）")) { try noMsg.unwrap() }
    }

    @Test func recordPageLenient() throws {
        let page = try decode(AttendanceRecordPage.self, #"{"records":[{"day":"2025-11-03","courseName":"高等数学","roomName":"西3-406","atdStateId":"2","atdStateName":"迟到","atdTime":"2025-11-03 08:03:10","periodConnect":"1-2"},{"day":"2025-11-04","courseName":"英语","atdStateId":100}],"total_record":"41","total_page":3,"page_index":1}"#)
        #expect(page.records.count == 2)
        #expect(page.records[0].state == .late)
        #expect(page.records[1].state == .noNeed)
        #expect(page.records[1].roomName == "")
        #expect(page.totalRecord == 41 && page.totalPage == 3)
    }

    @Test func unknownStateId() {
        #expect(AttendanceState(id: 77) == .unknown)
        #expect(AttendanceState(id: nil) == .unknown)
        #expect(AttendanceState(id: 4) == .absent)
        #expect(AttendanceState(id: 5) == .notStarted)
    }

    @Test func everyStateHasTextLabel() {
        let all: [AttendanceState] = [.normal, .late, .absent, .notStarted, .noNeed, .unknown]
        #expect(all.allSatisfy { !$0.label.isEmpty })
        #expect(Set(all.map(\.label)).count == all.count)
    }

    @Test func summaryCounts() {
        let recs = [1, 1, 2, 4, 5, 100, 9].map { AttendanceRecord(day: "2025-11-03", courseName: "x\($0)", stateId: $0) }
        let s = AttendanceSummary(recs)
        #expect(s.normal == 2 && s.late == 1 && s.absent == 1 && s.other == 3 && s.total == 7)
    }
}

@Suite struct AttendanceCalendarTests {
    let calendar = AttendanceCalendar(calendarId: 1, calendarName: "2025-1", firstWeekBegin: "2025-09-01 00:00:00", weekTotal: 20)

    @Test func currentWeekWithinRange() {
        let day = { (s: String) -> Date in AttendanceDay.parse(s, calendar: cal)! }
        #expect(calendar.currentWeek(now: day("2025-09-01"), calendar: cal) == 1)
        #expect(calendar.currentWeek(now: day("2025-09-07"), calendar: cal) == 1)
        #expect(calendar.currentWeek(now: day("2025-09-08"), calendar: cal) == 2)
        #expect(calendar.currentWeek(now: day("2025-11-05"), calendar: cal) == 10)
    }

    @Test func outOfRangeFallsBackToWeekOne() {
        let day = { (s: String) -> Date in AttendanceDay.parse(s, calendar: cal)! }
        #expect(calendar.currentWeek(now: day("2025-08-01"), calendar: cal) == 1)
        #expect(calendar.currentWeek(now: day("2026-06-01"), calendar: cal) == 1)
    }

    @Test func dayParsing() {
        #expect(AttendanceDay.parse("2025-11-03T00:00:00.000+0800", calendar: cal) != nil)
        #expect(AttendanceDay.parse("x", calendar: cal) == nil)
    }
}

@Suite struct AttendanceScheduleTests {
    // 3 行（节次 1–3）× 列 0..7（0 是表头列）。周一第 1–2 节是"高数"（connectCount 1），周三第 3 节是"英语"（connectCount 0 → 不算）
    let json = """
    {"resTableRankList":[
      {"courses":[{"subjectName":"第1节"},{"weekDay":"2025-11-03","subjectName":"高等数学","connectCount":1},{},{},{},{},{},{}]},
      {"courses":[{"subjectName":"第2节"},{"weekDay":"2025-11-03","subjectName":"高等数学","connectCount":0},{},{},{},{},{},{}]},
      {"courses":[{"subjectName":"第3节"},{},{},{"weekDay":"2025-11-05","subjectName":"大学物理","connectCount":2},{},{},{},{}]},
      {"courses":[{},{},{},{"weekDay":"2025-11-05","subjectName":"大学物理","connectCount":0},{},{},{},{}]},
      {"courses":[{},{},{},{"weekDay":"2025-11-05","subjectName":"大学物理","connectCount":0},{},{},{},{}]}
    ]}
    """

    @Test func parsesMergedCells() throws {
        let table = try decode(AttendanceScheduleTable.self, json)
        let courses = table.courses()
        #expect(courses.count == 2)
        let math = courses.first { $0.name == "高等数学" }
        #expect(math?.weekday == 1 && math?.firstPeriod == 1 && math?.lastPeriod == 2 && math?.day == "2025-11-03")
        let physics = courses.first { $0.name == "大学物理" }
        #expect(physics?.weekday == 3 && physics?.firstPeriod == 3 && physics?.lastPeriod == 5)
    }

    @Test func emptyAndMalformed() throws {
        #expect(try decode(AttendanceScheduleTable.self, #"{}"#).courses().isEmpty)
        #expect(try decode(AttendanceScheduleTable.self, #"{"resTableRankList":[{"courses":[]}]}"#).courses().isEmpty)
    }
}

@Suite struct AttendanceAPITests {
    @Test func callsAttendanceEndpointsAndUnwraps() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /attendance/index-data", json: Data(#"{"data":{"code":600,"msg":"","data":{"calendarList":[{"calendarId":18,"calendarName":"2025-1","firstWeekBegin":"2025-09-01","weekTotal":20,"isCurrent":1}]}}}"#.utf8))
        mock.stub("GET /attendance/personal-data", json: Data(#"{"data":{"code":600,"data":{"records":[{"day":"2025-11-03","courseName":"高等数学","atdStateId":1,"atdStateName":"正常"}],"total_record":1,"total_page":1,"page_index":1}}}"#.utf8))
        let api = AttendanceAPI(backend: mock)
        let calendars = try await api.calendars()
        #expect(calendars.first?.calendarId == 18)
        let page = try await api.records(calendarId: 18)
        #expect(page.records.first?.state == .normal)
    }

    @Test func innerErrorBecomesInvalidData() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /attendance/index-data", json: Data(#"{"data":{"code":403,"msg":"无权限","data":null}}"#.utf8))
        await #expect(throws: GxuError.invalidData("无权限")) { _ = try await AttendanceAPI(backend: mock).calendars() }
    }

    @Test func sessionExpiredPropagates() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /attendance/index-data", error: GxuError.sessionExpired(.attendance))
        await #expect(throws: GxuError.sessionExpired(.attendance)) { _ = try await AttendanceAPI(backend: mock).calendars() }
    }
}

@Suite struct AttendanceGroupingTests {
    @Test func groupsByDayDescending() {
        let recs = [
            AttendanceRecord(day: "2025-11-03", courseName: "a", stateId: 1),
            AttendanceRecord(day: "2025-11-05", courseName: "b", stateId: 1),
            AttendanceRecord(day: "2025-11-03", courseName: "c", stateId: 2),
        ]
        let groups = AttendanceDayGroup.group(recs)
        #expect(groups.map(\.day) == ["2025-11-05", "2025-11-03"])
        #expect(groups[1].records.count == 2)
    }
}
