import Foundation
import GxuAuth
import GxuFoundation
import ScheduleKit
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

private func day(_ s: String) -> Date { AttendanceDay.parse(s, calendar: cal)! }

@Suite struct AttendanceDecodingTests {
    @Test func calendarIdFormulaMatchesRN() {
        #expect(AttendanceCalendarID.id(year: 2025, term: 1) == 18)
        #expect(AttendanceCalendarID.id(year: 2025, term: 2) == 19)
        #expect(AttendanceCalendarID.id(year: 2026, term: 1) == 20)
    }

    @Test func recordDecodesRNFields() throws {
        let r = try decode(AttendanceRecord.self, #"{"date":"2025-11-03","courseName":"高等数学","roomName":"西3-406","periodRange":"1,2","periodLabel":"第1-2节","statusCode":2,"statusName":"迟到"}"#)
        #expect(r.date == "2025-11-03" && r.periodText == "第1-2节" && r.periodRange == "1,2")
        #expect(r.state == .late && r.isAbnormal)
        let b = try decode(AttendanceRecord.self, #"{"date":"2025-11-04","courseName":"英语","periodRange":"3,4","statusCode":"1"}"#)
        #expect(b.periodText == "3,4" && b.state == .normal && !b.isAbnormal && b.roomName == "")
        #expect(try decode(AttendanceRecord.self, #"{}"#).state == .unknown)
    }

    @Test func pageDecodesItemsAndToleratesNull() throws {
        #expect(try decode(AttendanceRecordPage.self, #"{"items":[{"date":"2025-11-03","courseName":"a","statusCode":1}]}"#).items.count == 1)
        #expect(try decode(AttendanceRecordPage.self, #"{}"#).items.isEmpty)
    }

    @Test func statesAndLabels() {
        #expect(AttendanceState(id: 77) == .unknown && AttendanceState(id: nil) == .unknown)
        #expect(AttendanceState(id: 4) == .absent && AttendanceState(id: 5) == .notStarted)
        let all: [AttendanceState] = [.normal, .late, .absent, .notStarted, .noNeed, .unknown]
        #expect(all.allSatisfy { !$0.label.isEmpty } && Set(all.map(\.label)).count == all.count)
    }

    @Test func summaryCounts() {
        let codes = [1, 1, 2, 4, 5, 100, 9]
        let recs = codes.map { AttendanceRecord(date: "2025-11-03", courseName: "x\($0)", statusCode: $0) }
        let s = AttendanceSummary(recs)
        #expect(s.normal == 2 && s.late == 1 && s.absent == 1 && s.other == 3 && s.total == 7)
    }

    @Test func hugeNumbersDoNotTrap() throws {
        let r = try decode(AttendanceRecord.self, #"{"date":"2025-11-03","courseName":"a","statusCode":1e30}"#)
        #expect(r.statusCode == nil && r.state == .unknown)
    }
}

@Suite struct AttendanceScheduleTests {
    @Test func parsesCellsLikeRN() throws {
        let json = """
        {"totalWeeks":18,"rows":[
          {"date":"2025-11-03","courses":[
            {"date":"2025-11-03","subjectId":7,"subjectName":"高等数学","periods":[1,2],"connectedCount":1,"roomName":"西3-406"},
            {"subjectId":0,"subjectName":""},
            {"date":"","subjectId":9,"subjectName":"用行日期","periods":[3,4],"roomName":""},
            {"date":"2025-11-04","subjectId":8,"subjectName":"单节","periods":[5,5]},
            {"date":"2025-11-05","subjectId":10,"subjectName":"没有节次","connectedCount":2}
          ]}
        ]}
        """
        let table = try decode(AttendanceSchedule.self, json)
        #expect(table.totalWeeks == 18)
        let courses = table.courses()
        #expect(courses.map(\.name) == ["高等数学", "用行日期", "没有节次"])
        #expect(courses[0].id == "2025-11-03-1,2" && courses[0].room == "西3-406")
        #expect(courses[1].day == "2025-11-03" && courses[1].firstPeriod == 3 && courses[1].lastPeriod == 4)
        #expect(courses[2].firstPeriod == 1 && courses[2].lastPeriod == 3)
    }

    @Test func emptyAndMalformed() throws {
        #expect(try decode(AttendanceSchedule.self, #"{}"#).courses().isEmpty)
        #expect(try decode(AttendanceSchedule.self, #"{"totalWeeks":20}"#).totalWeeks == 20)
        #expect(try decode(AttendanceSchedule.self, #"{"rows":[{"courses":[]}]}"#).courses().isEmpty)
    }

    @Test func hugeConnectedCountIsClampedNotTrapped() throws {
        let json = #"{"rows":[{"date":"2025-11-03","courses":[{"subjectId":1,"subjectName":"X","connectedCount":9223372036854775807}]}]}"#
        let c = try decode(AttendanceSchedule.self, json).courses()
        #expect(c.count == 1 && c[0].lastPeriod == 101)
    }

    @Test func statusMatchesRecordsByDateAndPeriodRange() {
        let course = AttendanceCourse(day: "2025-11-03", name: "高数", room: "", firstPeriod: 1, lastPeriod: 2)
        #expect(course.id == "2025-11-03-1,2")
        let record = AttendanceRecord(date: "2025-11-03", courseName: "高数", statusCode: 2, periodRange: "1,2")
        #expect("\(record.date)-\(record.periodRange)" == course.id)
    }
}

@Suite struct AttendanceFilterTests {
    private func r(_ date: String, _ code: Int) -> AttendanceRecord { AttendanceRecord(date: date, courseName: date, statusCode: code) }

    @Test func recordFiltersDistinguishAbnormalFromRecentRecords() {
        let now = day("2025-11-20")
        let list = [r("2025-11-20", 1), r("2025-11-13", 1), r("2025-11-12", 1), r("2025-09-01", 2), r("2025-09-02", 4), r("2025-09-03", 1), r("bad", 1)]
        let visible = AttendanceFilter.abnormalAndRecent.visible(list, now: now, calendar: cal).map(\.date)
        #expect(visible == ["2025-11-20", "2025-11-13", "2025-09-01", "2025-09-02", "bad"])
        #expect(AttendanceFilter.abnormal.visible(list, now: now, calendar: cal).map(\.date) == ["2025-09-01", "2025-09-02"])
        #expect(AttendanceFilter.all.visible(list, now: now, calendar: cal) == list)
    }
}

@Suite struct AttendanceWeekTests {
    private let days = [TermStartDay(year: 2025, term: 1, day: "2025-09-01", week: 20), TermStartDay(year: 2025, term: 2, day: "2026-03-02", week: 18)]

    @Test func weekFromTheSelectedTermStartDay() {
        #expect(AttendanceWeek.initial(year: 2025, term: 1, startDays: days, now: day("2025-09-01"), calendar: cal) == 1)
        #expect(AttendanceWeek.initial(year: 2025, term: 1, startDays: days, now: day("2025-11-05"), calendar: cal) == 10)
        #expect(AttendanceWeek.initial(year: 2025, term: 2, startDays: days, now: day("2026-03-09"), calendar: cal) == 2)
    }

    @Test func clampedAndMissingStartDay() {
        #expect(AttendanceWeek.initial(year: 2025, term: 1, startDays: days, now: day("2025-08-01"), calendar: cal) == 1)
        #expect(AttendanceWeek.initial(year: 2025, term: 1, startDays: days, now: day("2026-06-01"), calendar: cal) == 20)
        #expect(AttendanceWeek.initial(year: 2030, term: 1, startDays: days, now: day("2025-11-05"), calendar: cal) == 1)
    }
}

@Suite struct AttendanceDateTests {
    @Test func invalidDatesAreNotShifted() {
        #expect(AttendanceDay.parse("2026-02-30", calendar: cal) == nil)
        #expect(AttendanceDay.parse("2026-13-01", calendar: cal) == nil)
        #expect(AttendanceDay.parse("2025-09-01 00:00:00", calendar: cal) != nil)
    }
}

@Suite struct AttendanceAPITests {
    @Test func callsV2EndpointsAndMapsFields() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /attendance/v2/personal", json: Data(#"{"code":200,"data":{"items":[{"date":"2025-11-03","courseName":"高等数学","statusCode":1,"statusName":"正常","periodRange":"1,2"}]}}"#.utf8))
        mock.stub("GET /attendance/v2/schedule", json: Data(#"{"code":200,"data":{"totalWeeks":18,"rows":[{"date":"2025-11-03","courses":[{"subjectId":1,"subjectName":"高数","periods":[1,2]}]}]}}"#.utf8))
        let api = AttendanceAPI(backend: mock)
        let records = try await api.records(year: 2025, term: 1)
        #expect(records.first?.state == .normal)
        let schedule = try #require(await api.schedule(year: 2025, term: 1, week: 3, userId: 1))
        #expect(schedule.totalWeeks == 18 && schedule.courses.count == 1)
        #expect(mock.calls == ["GET /attendance/v2/personal", "GET /attendance/v2/schedule"])
    }

    @Test func nullDataIsEmpty() async throws {
        let mock = MockBackendAPI()
        mock.stub("GET /attendance/v2/personal", json: Data(#"{"data":null}"#.utf8))
        mock.stub("GET /attendance/v2/schedule", json: Data(#"{"data":null}"#.utf8))
        let api = AttendanceAPI(backend: mock)
        #expect(try await api.records(year: 2025, term: 1).isEmpty)
        #expect(try await api.schedule(year: 2025, term: 1, week: 1, userId: 1) == nil)
    }

    @Test func sessionExpiredPropagates() async {
        let mock = MockBackendAPI()
        mock.stub("GET /attendance/v2/personal", error: GxuError.sessionExpired(.attendance))
        await #expect(throws: GxuError.sessionExpired(.attendance)) { _ = try await AttendanceAPI(backend: mock).records(year: 2025, term: 1) }
    }
}

@Suite struct AttendanceGroupingTests {
    @Test func recordsGroupByDayDescending() {
        let recs = [
            AttendanceRecord(date: "2025-11-03", courseName: "a", statusCode: 1),
            AttendanceRecord(date: "2025-11-05", courseName: "b", statusCode: 1),
            AttendanceRecord(date: "2025-11-03", courseName: "c", statusCode: 2),
        ]
        let groups = AttendanceDayGroup.group(recs)
        #expect(groups.map(\.day) == ["2025-11-05", "2025-11-03"] && groups[1].records.count == 2)
    }

    @Test func coursesGroupByDayAscendingAndSortByPeriod() {
        let courses = [
            AttendanceCourse(day: "2025-11-05", name: "c", room: "", firstPeriod: 3, lastPeriod: 4),
            AttendanceCourse(day: "2025-11-03", name: "b", room: "", firstPeriod: 5, lastPeriod: 6),
            AttendanceCourse(day: "2025-11-03", name: "a", room: "", firstPeriod: 1, lastPeriod: 2),
        ]
        let groups = AttendanceDayGroup.groupCourses(courses)
        #expect(groups.map(\.day) == ["2025-11-03", "2025-11-05"] && groups[0].courses.map(\.name) == ["a", "b"])
    }
}
