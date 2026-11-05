import Foundation
import Testing
@testable import FeatureCampus

struct MapDataTests {
    @Test func placesLoadFromBundledJSON() {
        #expect(CampusPlaces.all.count > 100)
        #expect(CampusPlaces.types.first == "体育场" || CampusPlaces.types.contains("教学楼"))
        #expect(CampusPlaces.all.allSatisfy { !$0.fullName.isEmpty && !$0.name.isEmpty })
    }

    @Test func roomTextMatchesBuilding() {
        #expect(CampusPlaces.place(forRoom: "6A-427")?.name == "东校园第六教学楼")
        #expect(CampusPlaces.place(forRoom: "东10-B406")?.name == "东校园第十教学楼")
        #expect(CampusPlaces.place(forRoom: "西3-406")?.name == "西校园第三教学楼")
        #expect(CampusPlaces.place(forRoom: "不存在的教室") == nil)
        // 只占位用的 `#` 模式不能匹配任何教室
        #expect(CampusPlaces.all.filter { $0.pattern == nil }.allSatisfy { !$0.matches(room: "西3-406") })
    }

    @Test func searchMatchesNameFullNameAndAliases() throws {
        let sixth = try #require(CampusPlaces.all.first { $0.name == "东校园第六教学楼" })
        #expect(sixth.matches(query: "六教"))        // 俗称
        #expect(sixth.matches(query: "东校园"))      // 名称
        #expect(sixth.matches(query: ""))
        #expect(!sixth.matches(query: "食堂"))
    }

    @Test func mapsURLEncodesFullName() throws {
        let place = try #require(CampusPlaces.all.first)
        let url = try #require(place.mapsURL)
        #expect(url.host == "maps.apple.com")
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == place.fullName)
    }

    @Test func buildingsAndFloorImages() throws {
        #expect(TeachBuildings.all.count == 4)
        #expect(TeachBuildings.all.reduce(0) { $0 + $1.floors.count } == 18)
        let floor = try #require(TeachBuildings.all.first { $0.id == "erjiao" }?.floors.first { $0.id == "2-4" })
        let url = try #require(TeachBuildings.imageURL(floor))
        #expect(url.absoluteString == "https://file.unde.site/GxuToolApp/resource/img/plan_view/2/2-2~4.webp")
    }
}
