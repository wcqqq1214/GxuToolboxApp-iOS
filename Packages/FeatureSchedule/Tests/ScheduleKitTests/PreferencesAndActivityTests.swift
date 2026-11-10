import Foundation
import GxuFoundation
import GxuStorage
import GxuTestSupport
import Testing
@testable import ScheduleKit

struct PreferencesAndActivityTests {
    @Test func preferencesDecodeLeniently() throws {
        let empty = try JSONDecoder().decode(SchedulePreferences.self, from: Data("{}".utf8))
        #expect(empty == SchedulePreferences())

        // 旧版本只存了一部分字段、含已下线字段：保留顺序和开关，补上新字段
        let old = #"{"palette":"vivid","courseDetail":[{"id":"teacher","label":"老师","isShown":false},{"id":"gone","label":"x","isShown":true},{"id":"time","label":"时间","isShown":true}]}"#
        let decoded = try JSONDecoder().decode(SchedulePreferences.self, from: Data(old.utf8))
        #expect(decoded.palette == .vivid)
        #expect(decoded.courseDetail.prefix(2).map(\.id) == ["teacher", "time"])
        #expect(decoded.courseDetail[0].label == "老师" && !decoded.courseDetail[0].isShown)
        #expect(!decoded.courseDetail.contains { $0.id == "gone" })
        #expect(Set(decoded.courseDetail.map(\.id)) == Set(SchedulePreferences.courseFieldDefaults.map(\.id)))
    }

    @MainActor @Test func storePersistsChanges() {
        let shared = UserDefaultsSharedStore(suiteName: "test.prefs.\(UUID().uuidString)")
        let store = SchedulePreferencesStore(shared: shared)
        store.value.palette = .morandi
        store.value.courseDetail[0].isShown = false
        let reloaded = SchedulePreferencesStore(shared: shared)
        #expect(reloaded.value.palette == .morandi)
        #expect(!reloaded.value.courseDetail[0].isShown)
        reloaded.reset()
        #expect(SchedulePreferencesStore(shared: shared).value == SchedulePreferences())
    }

    // MARK: 自定义日程

    @Test func activityBecomesCourse() {
        let activity = CustomActivity(name: " 社团例会 ", weekday: 3, begin: 9, end: 10, weekFrom: 2, weekTo: 4)
        #expect(activity.isValid)
        let course = activity.course
        #expect(course.isCustom && course.courseName == "社团例会")
        #expect(course.weeks == [2, 3, 4] && course.weekday == 3 && course.begin == 9 && course.end == 10)
        #expect(activity.weekText == "第 2-4 周")
        #expect(CustomActivity(weekFrom: 3, weekTo: 3).weekText == "第 3 周")
    }

    @Test func invalidActivities() {
        #expect(!CustomActivity(name: "  ").isValid)
        #expect(!CustomActivity(name: "x", begin: 5, end: 4).isValid)
        #expect(!CustomActivity(name: "x", end: 14).isValid)
        #expect(!CustomActivity(name: "x", weekFrom: 5, weekTo: 2).isValid)
    }

    @Test func customCourseIdsDoNotCollideWithRealOnes() {
        let real = course("同名", weekday: 1, 1, 2, weeks: [1])
        var custom = real
        custom.customID = "abc"
        #expect(real.id != custom.id)
    }

    @Test func activitiesPersistPerStudentAndTerm() async throws {
        let repository = ScheduleRepository(backend: MockBackendAPI(), database: try .inMemory(features: [ScheduleKit.migrations]))
        let t1 = AcademicTerm(year: 2026, term: 1)
        var a = CustomActivity(name: "A", weekFrom: 1, weekTo: 2)
        try await repository.saveCustomActivity(a, studentId: "S", term: t1)
        a.name = "A2"
        try await repository.saveCustomActivity(a, studentId: "S", term: t1)   // 覆盖
        try await repository.saveCustomActivity(CustomActivity(name: "B"), studentId: "S", term: t1)
        #expect(await repository.customActivities(studentId: "S", term: t1).map(\.name).sorted() == ["A2", "B"])
        #expect(await repository.customActivities(studentId: "T", term: t1).isEmpty)
        #expect(await repository.customActivities(studentId: "S", term: AcademicTerm(year: 2026, term: 2)).isEmpty)
        try await repository.deleteCustomActivity(id: a.id, studentId: "S", term: t1)
        #expect(await repository.customActivities(studentId: "S", term: t1).map(\.name) == ["B"])
    }
}

// MARK: 实验课（RN v2.2 customEvent）

struct CustomActivityLabTests {
    @Test func weeksCanBeDiscontinuousAndFeedTheCourse() {
        let lab = CustomActivity(name: "大学物理实验", location: " 实验楼 301 ", teacher: "教师甲", weeks: [10, 1, 2, 3, 12, 3])
        #expect(lab.weeks == [1, 2, 3, 10, 12])
        #expect(lab.weekText == "第 1-3,10,12 周" && lab.weeksInputText == "1-3,10,12")
        #expect(lab.course.weeks == [1, 2, 3, 10, 12] && lab.course.venueName == "实验楼 301" && lab.course.teacher == "教师甲")
        #expect(lab.course.courseCategory == "实验课")
    }

    @Test func parseTeachingWeeksLikeRN() throws {
        #expect(try TeachingWeeks.parse("1-8,10，12", weekCount: 18) == [1, 2, 3, 4, 5, 6, 7, 8, 10, 12])
        #expect(try TeachingWeeks.parse(" 3 - 4 , 3 ", weekCount: 18) == [3, 4])
        for bad in ["", "1,,2", "a", "1-", "-3", "1-2-3", "１", "1.5"] {
            #expect(throws: TeachingWeeks.ParseError.format) { try TeachingWeeks.parse(bad, weekCount: 18) }
        }
        for bad in ["0", "5-3", "19", "1-19"] {
            #expect(throws: TeachingWeeks.ParseError.range(weekCount: 18)) { try TeachingWeeks.parse(bad, weekCount: 18) }
        }
        #expect(TeachingWeeks.ParseError.format.errorDescription == "教学周格式示例：1-8,10,12")
        #expect(TeachingWeeks.ParseError.range(weekCount: 18).errorDescription == "教学周须在 1—18 之间")
    }

    @Test func validationFollowsRNSchema() {
        func lab(_ edit: (inout CustomActivity) -> Void) -> String? {
            var a = CustomActivity(name: "实验", weeks: [1]); edit(&a); return a.validationMessage
        }
        #expect(lab { _ in } == nil)
        #expect(lab { $0.name = "  " } == "请输入实验课名称")
        #expect(lab { $0.name = String(repeating: "名", count: 101) } == "名称最多 100 字")
        #expect(lab { $0.location = String(repeating: "a", count: 201) } == "地点最多 200 字")
        #expect(lab { $0.teacher = String(repeating: "a", count: 101) } == "教师最多 100 字")
        #expect(lab { $0.note = String(repeating: "a", count: 2001) } == "备注最多 2000 字")
        #expect(lab { $0.weeks = [] } == "请选择教学周")
        #expect(lab { $0.weeks = [54] } == "教学周须在 1—53 之间")
        #expect(lab { $0.begin = 5; $0.end = 4 } == "结束节次不能早于开始节次")
    }

    @Test func legacyStoredJSONStillDecodesAndKeepsWeeksOnRoundTrip() throws {
        let legacy = #"{"id":"a","name":"老日程","note":"备注","weekday":2,"begin":1,"end":2,"weekFrom":3,"weekTo":5,"colorHex":11926999}"#
        let old = try JSONDecoder().decode(CustomActivity.self, from: Data(legacy.utf8))
        #expect(old.weeks == [3, 4, 5] && old.location.isEmpty && old.teacher.isEmpty && old.note == "备注")
        let again = try JSONDecoder().decode(CustomActivity.self, from: JSONEncoder().encode(CustomActivity(id: "b", name: "新", weeks: [1, 3, 9])))
        #expect(again.weeks == [1, 3, 9] && again.weekFrom == 1 && again.weekTo == 9)
    }

    @Test func labsOnMakeupWorkDaysAreHiddenButRegularCoursesStay() {
        // RN：实验课图层 needShift 为真、没有 showPreShiftItems。9-21 周一补 9-25（周五）的课
        let lab = CustomActivity(name: "实验", weekday: 1, begin: 5, end: 6, weeks: Array(1...18))
        let campus = CampusCalendar(timeShift: [ShiftRule(workDate: "2026-09-21", restDate: "2026-09-25")])
        let all = ScheduleExpander.occurrences(of: Schedule(theoryList: [course("大学英语", weekday: 1, 3, 4, weeks: Array(1...18)), lab.course]), in: term)
        let result = CalendarOverlay.apply(to: all, calendar: campus, term: term).occurrences.filter { $0.date == at("2026-09-21") }
        #expect(result.map(\.course.courseName) == ["大学英语"])
    }
}
