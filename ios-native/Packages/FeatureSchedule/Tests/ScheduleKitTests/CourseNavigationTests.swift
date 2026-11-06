import Foundation
import Testing
@testable import ScheduleKit

struct CourseNavigationTests {
    @Test func sportsCollegeUsesVenueKeyword() {
        #expect(CourseNavigation.target(building: "体育学院", venue: "北篮球场")?.mapKeyword == "广西大学行健图书馆行健馆")
        #expect(CourseNavigation.target(building: "体育学院", venue: "西体育馆")?.mapKeyword == "广西大学西校园综合体育馆")
        #expect(CourseNavigation.target(building: "体育学院", venue: "东田径场")?.mapKeyword == "广西大学东校园体育场")
        #expect(CourseNavigation.target(building: "体育学院", venue: "室内馆")?.mapKeyword == nil)
    }

    @Test func ordinaryRoomHasNoKeyword() {
        let target = CourseNavigation.target(building: "6A", venue: "427")
        #expect(target?.room == "6A427")
        #expect(target?.mapKeyword == nil)
    }

    @Test func emptyLocationHasNoTarget() {
        #expect(CourseNavigation.target(building: "", venue: "") == nil)
    }
}

struct CourseLocationDisplayTests {
    @Test func courseShowsOnlyTheRoomButNavigationKeepsTheBuilding() {
        let course = TheoryCourse(building: "西二教", venueName: "西2-202", courseName: "高等数学", weeks: [1], weekday: 1)
        #expect(course.locationText == "西2-202")
        #expect(CourseNavigation.target(building: course.building, venue: course.venueName)?.room == "西二教西2-202")
        let noRoom = TheoryCourse(building: "西二教", venueName: "", courseName: "高等数学", weeks: [1], weekday: 1)
        #expect(noRoom.locationText == "西二教")
    }

    @Test func widgetCourseRoomUsesTheSameText() {
        let course = TheoryCourse(building: "西三教", venueName: "西3-406", courseName: "高等数学", weeks: [1], weekday: 1)
        let occurrence = CourseOccurrence(course: course, week: 1, date: at("2026-09-07"), startsAt: at("2026-09-07 08:00"), endsAt: at("2026-09-07 09:40"), weekday: 1, shiftedFrom: nil)
        #expect(WidgetCourse(occurrence, calendar: shanghai).room == "西3-406")
    }
}
