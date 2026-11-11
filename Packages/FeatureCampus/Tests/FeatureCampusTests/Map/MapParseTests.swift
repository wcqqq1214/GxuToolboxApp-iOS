import Foundation
import GxuFoundation
import GxuTestSupport
import ScheduleKit
import Testing
@testable import FeatureCampus

struct MapParseTests {
    private func name(_ text: String) -> String? { CampusPlaces.parse(text)?.name }

    @Test func dataIsTheRNListWithUniqueNames() {
        #expect(CampusPlaces.all.count == 123)
        #expect(Set(CampusPlaces.all.map(\.name)).count == 123)
        #expect(CampusPlaces.all.first?.name == "西体育馆")
        #expect(CampusPlaces.all.first { $0.name == "行健图书馆" }?.pattern == "^行健图书馆")
        #expect(CampusPlaces.all.first { $0.name == "行健田径场、体育馆" }?.fullName == "广西大学北校区体育馆")
        #expect(CampusPlaces.all.first { $0.name == "行健篮球场" }?.fullName == "广西大学北校区体育馆")
    }

    @Test func threeStagesInRNOrder() {
        #expect(name("6A-427") == "东校园第六教学楼")
        #expect(name("东10-B406") == "东校园第十教学楼")
        #expect(name("西3-406") == "西校园第三教学楼")
        #expect(name("大礼堂") == "西校园大礼堂")
        #expect(name("西综合511") == "西校园综合楼")
        #expect(name("广西大学西校园第三教学楼") == "西校园第三教学楼")
        #expect(name("去 西校园第二教学楼 上课") == "西校园第二教学楼")
        #expect(name("东六教 | 6A-113") == "东校园第六教学楼")
        #expect(name("西二教 | 西2-202") == "西校园第二教学楼")
        #expect(name("不存在的教室") == nil)
    }

    @Test func whitespaceIsNormalizedAndEmptyIsUnparsed() {
        #expect(name("") == nil)
        #expect(name("  \n ") == nil)
        #expect(name("  西3-406  ") == "西校园第三教学楼")
        #expect(name("西3\u{3000}406") == "西校园第三教学楼")
        #expect(name(" | 6A-113") == "东校园第六教学楼")
    }


    private func fixtureData(_ file: String) throws -> [String: Any] {
        let data = try loadFixture(file, bundle: .module)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object?["data"] as? [String: Any] ?? object ?? [:]
    }

    @Test func realCourseRoomsResolveLikeRN() throws {
        let data = try fixtureData("schedule-personal")
        let courses = try #require(data["theoryList"] as? [[String: Any]])
        var resolved: [String: String] = [:]
        for course in courses {
            let building = course["building"] as? String ?? ""
            let venue = course["venueName"] as? String ?? ""
            let target = try #require(CourseNavigation.target(building: building, venue: venue))
            resolved[target.text] = name(target.text) ?? "—"
        }
        let expected: [String: String] = [
            "东六教 | 6A-113": "东校园第六教学楼", "东六教 | 6A-116": "东校园第六教学楼", "东六教 | 6A-217": "东校园第六教学楼",
            "东六教 | 6A-305": "东校园第六教学楼", "东六教 | 6A-319": "东校园第六教学楼", "东六教 | 6A-323": "东校园第六教学楼",
            "东六教 | 6A-405": "东校园第六教学楼", "东六教 | 6A-408": "东校园第六教学楼", "东六教 | 6A-415": "东校园第六教学楼",
            "东六教 | 6A-505": "东校园第六教学楼", "东六教 | 6A-520": "东校园第六教学楼", "东六教 | 6A-608": "东校园第六教学楼",
            "东六教 | 6B-101": "东校园第六教学楼", "东十教 | 东10B-404": "东校园第十教学楼",
            "土木学院办公楼 | 土-502": "土木建筑工程学院", "土木学院办公楼 | 土木实验室": "土木建筑工程学院",
            "土木学院办公楼 | 土木实验室1": "土木建筑工程学院", "土木学院办公楼 | 土木实验室2": "土木建筑工程学院",
            "大礼堂 | 大礼堂": "西校园大礼堂", "综合楼 | 西综合511": "西校园综合楼", "西二教 | 西2-202": "西校园第二教学楼",
        ]
        #expect(resolved == expected)
    }

    @Test func realExamClassroomsResolveLikeRN() throws {
        let data = try loadFixture("exam", bundle: .module)
        let exams = try #require((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["data"] as? [[String: Any]])
        var resolved: [String: String] = [:]
        for exam in exams {
            let room = exam["classroom"] as? String ?? ""
            resolved[room] = name(room) ?? "—"
        }
        #expect(resolved == [
            "6A-210": "东校园第六教学楼", "6A-419": "东校园第六教学楼", "6B-101": "东校园第六教学楼", "6B-103": "东校园第六教学楼", "6B-104": "东校园第六教学楼",
            "西2-207": "西校园第二教学楼", "西3-204": "西校园第三教学楼", "西3-207": "西校园第三教学楼", "西3-302": "西校园第三教学楼",
        ])
    }

    @MainActor @Test func sportsCollegeKeywordSkipsParsing() throws {
        let target = try #require(CourseNavigation.target(building: "体育学院", venue: "西体育馆"))
        #expect(target.mapKeyword == "广西大学西校园综合体育馆")
        #expect(MapNavigation.plan(text: target.text, keyword: target.mapKeyword, installed: [.apple])
            == .open(keyword: "广西大学西校园综合体育馆", apps: [.apple]))
    }

    @MainActor @Test func planUsesParsedFullNameAndUnparsedStaysUnparsed() {
        #expect(MapNavigation.plan(text: "东六教 | 6A-113", installed: [.apple, .amap]) == .open(keyword: "广西大学东校园第六教学楼", apps: [.apple, .amap]))
        #expect(MapNavigation.plan(text: "未知楼 | 9Z-999", installed: [.apple]) == .unparsed)
        #expect(MapNavigation.plan(text: "东六教 | 6A-113", installed: []) == .noApp)
    }
}
