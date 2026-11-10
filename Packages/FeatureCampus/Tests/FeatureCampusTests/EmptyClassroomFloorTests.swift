import Foundation
import Testing
@testable import FeatureCampus

/// 用例取自 RN 的 `emptyClassroom/utils/__tests__/floor.test.ts`
struct EmptyClassroomFloorTests {
    private func floor(_ name: String, _ building: String? = nil) -> Int? { EmptyClassroomFloor.detectFloor(name, building: building) }

    @Test func infersFromTheLastRoomNumber() {
        #expect(floor("西1-101") == 1 && floor("教10-203") == 2 && floor("A101") == 1)
        #expect(floor("0501") == 5 && floor("1001") == 10 && floor("1203") == 12)
        #expect(floor("101-1") == 1 && floor("西1-10") == 1 && floor("10") == 1 && floor("21") == 2 && floor("01") == 1)
    }

    @Test func explicitFloorWins() {
        #expect(floor("3层101") == 3 && floor("3F") == 3 && floor("3F101") == 3 && floor("A3F101") == 3 && floor(" 3f ") == 3)
    }

    @Test func fullWidthDigitsAreNormalized() {
        #expect(floor("３层１０１") == 3 && floor("１０１") == 1 && floor("０５０１") == 5)
    }

    @Test func unrecognizableOrUndergroundIsNil() {
        #expect(floor("B1") == nil && floor("B1层101") == nil && floor("负1层101") == nil)
        #expect(floor("报告厅") == nil && floor("") == nil && floor("   ") == nil && floor("40层") == nil && floor("12345") == nil)
    }

    @Test func buildingNameDigitsAreNotFloors() {
        #expect(floor("教10-203", "教10") == 2)
        #expect(floor("教10-报告厅", "教10") == nil)
        #expect(floor("西1-101", "西1") == 1 && floor("东九教101", "东九教") == 1 && floor("A101", "a") == 1 && floor("A+B-101", "A+B") == 1)
    }

    private func room(_ id: Int64, _ building: String, _ name: String) -> RoomRecord {
        RoomRecord(id: id, building: building, name: name, placeType: "", seatCount: nil, seatCountForExam: nil, owner: "", allowToUse: "")
    }

    @Test func buildingsPutOtherFirstThenNaturalOrder() {
        let groups = EmptyClassroomFloor.groupBuildings([
            RoomBuildingSummary(building: "教10", roomCount: 30), RoomBuildingSummary(building: "", roomCount: 4), RoomBuildingSummary(building: "教2", roomCount: 20),
        ])
        #expect(groups.map(\.title) == ["其他楼栋", "教2", "教10"] && groups.map(\.roomCount) == [4, 20, 30])
        #expect(EmptyClassroomFloor.groupBuildings([]).isEmpty)
    }

    @Test func roomsGroupByFloorWithOtherFirst() {
        let rooms = [room(1, "教2", "301"), room(2, "教2", "报告厅"), room(3, "教2", "101"), room(4, "教2", "102"), room(5, "教2", "203")]
        let groups = EmptyClassroomFloor.groupRoomsByFloor(rooms)
        #expect(groups.map(\.title) == ["其他楼层", "1 层", "2 层", "3 层"])
        #expect(groups.map(\.floor) == [nil, 1, 2, 3])
        #expect(groups[1].rooms.map(\.name) == ["101", "102"])
    }

    @Test func searchSectionsAreBuildingDotFloor() {
        let sections = EmptyClassroomFloor.groupSearchResults([room(1, "教2", "101"), room(2, "", "X"), room(3, "教2", "201")])
        #expect(sections.map(\.title) == ["其他楼栋 · 其他楼层", "教2 · 1 层", "教2 · 2 层"])
    }
}
