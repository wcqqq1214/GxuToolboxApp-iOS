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
        #expect(activity.weekText == "第 2–4 周")
        #expect(CustomActivity(weekFrom: 3, weekTo: 3).weekText == "仅第 3 周")
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
