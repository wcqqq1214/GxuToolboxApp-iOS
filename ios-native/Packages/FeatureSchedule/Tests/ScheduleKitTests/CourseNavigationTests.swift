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
