import Foundation
import GxuFoundation
import GxuStorage
import GxuTestSupport
import ScheduleKit
import Testing

struct CourseRescheduleTests {
    @Test func oldCourseSnapshotsDecodeWithoutEnablingLookup() throws {
        let data = Data(#"{"theoryList":[{"courseName":"高等数学","weekday":1,"weeks":[1]}]}"#.utf8)
        let schedule = try JSONDecoder().decode(Schedule.self, from: data)
        let course = try #require(schedule.theoryList.first)
        #expect(course.courseName == "高等数学")
        #expect(course.classId == nil)
        #expect(!course.isRescheduled)
        #expect(course.rescheduleClassId == nil)
    }

    @Test func refreshedSchedulePersistsTeachingClassAndRescheduleFlag() async throws {
        let backend = MockBackendAPI()
        backend.stub("GET /jw/schedule/personal", json: """
        {"data":{"theoryList":[
            {"courseName":"高等数学","weekday":1,"weeks":[1],"classId":"class-123","isRescheduled":true},
            {"courseName":"线性代数","weekday":2,"weeks":[1],"classId":"class-456","isRescheduled":false},
            {"courseName":"大学物理","weekday":3,"weeks":[1],"isRescheduled":true}
        ]}}
        """)
        let repository = ScheduleRepository(backend: backend, database: try .inMemory(features: [ScheduleKit.migrations]))
        let term = AcademicTerm(year: 2026, term: 1)

        try await repository.refreshSchedule(studentId: "demo", term: term)
        let cached = try #require(await repository.cachedSchedule(studentId: "demo", term: term))
        #expect(cached.schedule.theoryList.map(\.rescheduleClassId) == ["class-123", nil, nil])
        #expect(backend.calls == ["GET /jw/schedule/personal"])
    }

    @Test func requestsRecordsWithTeachingClassIdAndJwAuthentication() async throws {
        let backend = MockBackendAPI()
        let path = "/jw/schedule/personal/reschedules"
        backend.stub("GET \(path)", json: """
        {"data":[{
            "type":"调课","reason":"教学安排","reasonCategory":"其他",
            "before":{"weeks":"1-2","weekday":"一","sections":"1-2","teacher":"张老师","venueName":"西一-101"},
            "after":{"weeks":"1-2","weekday":"二","sections":"3-4","teacher":"张老师","venueName":"西一-102"}
        }]}
        """)
        let repository = ScheduleRepository(backend: backend, database: try .inMemory(features: [ScheduleKit.migrations]))

        let records = try await repository.reschedules(classId: "class-123")
        let record = try #require(records.first)
        #expect(record.reason == "教学安排")
        #expect(record.before.weekday == "一")
        #expect(record.after.sections == "3-4")
        #expect(record.after.venueName == "西一-102")
        let request = try #require(backend.getRequests.first)
        #expect(request.path == path)
        #expect(request.query == ["classId": "class-123"])
        #expect(request.auth == .jw)

        backend.stub("GET \(path)", json: #"{"data":[]}"#)
        #expect(try await repository.reschedules(classId: "class-456").isEmpty)

        backend.stub("GET \(path)", error: .network("offline"))
        await #expect(throws: GxuError.self) {
            try await repository.reschedules(classId: "class-123")
        }
    }
}
