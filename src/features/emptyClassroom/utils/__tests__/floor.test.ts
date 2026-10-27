import {detectFloor, groupRoomsByBuilding} from "@/features/emptyClassroom/utils/floor.ts";
import type {RoomRecord} from "@/features/emptyClassroom/type";

/** 构造测试用教室行，只关心分组相关字段。 */
function makeRoom(building: string, name: string, id = 1): RoomRecord {
    return {
        id,
        building,
        name,
        placeType: "普通教室",
        seatCount: 60,
        seatCountForExam: null,
        owner: "",
        allowToUse: "",
        updatedAt: new Date(0),
    };
}

describe("detectFloor", () => {
    it("从房间号末段识别楼层", () => {
        expect(detectFloor("西1-101")).toBe(1);
        expect(detectFloor("教10-203")).toBe(2);
        expect(detectFloor("A101")).toBe(1);
        expect(detectFloor("0501")).toBe(5);
        expect(detectFloor("1001")).toBe(10);
        expect(detectFloor("1203")).toBe(12);
        expect(detectFloor("101-1")).toBe(1);
        expect(detectFloor("西1-10")).toBe(1);
        expect(detectFloor("10")).toBe(1);
        expect(detectFloor("21")).toBe(2);
        expect(detectFloor("01")).toBe(1);
    });

    it("优先识别显式楼层", () => {
        expect(detectFloor("3层101")).toBe(3);
        expect(detectFloor("3F")).toBe(3);
        expect(detectFloor("3F101")).toBe(3);
        expect(detectFloor("A3F101")).toBe(3);
        expect(detectFloor(" 3f ")).toBe(3);
    });

    it("全角数字按半角处理", () => {
        expect(detectFloor("３层１０１")).toBe(3);
        expect(detectFloor("１０１")).toBe(1);
        expect(detectFloor("０５０１")).toBe(5);
    });

    it("无法识别时返回 null", () => {
        expect(detectFloor("B1")).toBeNull();
        expect(detectFloor("B1层101")).toBeNull();
        expect(detectFloor("负1层101")).toBeNull();
        expect(detectFloor("报告厅")).toBeNull();
        expect(detectFloor("")).toBeNull();
        expect(detectFloor("   ")).toBeNull();
        expect(detectFloor("40层")).toBeNull();
        expect(detectFloor("12345")).toBeNull();
    });

    it("不会把楼栋名里的数字误当楼层", () => {
        // “教10-”只是楼栋名，真正决定楼层的是末段房间号 203。
        expect(detectFloor("教10-203", "教10")).toBe(2);
        // 去掉楼栋名后没有房间号，应归入“其他教室”。
        expect(detectFloor("教10-报告厅", "教10")).toBeNull();
    });

    it("按字面量、忽略大小写地去掉楼栋名", () => {
        expect(detectFloor("西1-101", "西1")).toBe(1);
        expect(detectFloor("东九教101", "东九教")).toBe(1);
        expect(detectFloor("A101", "a")).toBe(1);
        // 楼栋名包含正则特殊字符时也要按字面量匹配。
        expect(detectFloor("A+B-101", "A+B")).toBe(1);
    });
});

describe("groupRoomsByBuilding", () => {
    const rooms = [
        makeRoom("教10", "教10-203", 1),
        makeRoom("教10", "教10-101", 2),
        makeRoom("教10", "教10-报告厅", 3),
        makeRoom("教2", "303", 4),
        makeRoom("教2", "101", 5),
        makeRoom("教2", "201", 6),
    ];

    it("按楼栋名称做中文数字排序并统计楼层/教室数", () => {
        const groups = groupRoomsByBuilding(rooms);
        expect(groups.map(group => group.building)).toEqual(["教2", "教10"]);

        const [jiao2, jiao10] = groups;
        expect(jiao2.floorCount).toBe(3);
        expect(jiao2.unknownFloorCount).toBe(0);
        expect(jiao2.rooms).toHaveLength(3);

        expect(jiao10.floorCount).toBe(2);
        expect(jiao10.unknownFloorCount).toBe(1);
        expect(jiao10.rooms).toHaveLength(3);
    });

    it("楼层升序，“其他教室”永远最后", () => {
        const groups = groupRoomsByBuilding(rooms);
        const jiao10 = groups[1];
        expect(jiao10.floors.map(group => group.title)).toEqual(["1 层", "2 层", "其他教室"]);
        expect(jiao10.floors.map(group => group.floor)).toEqual([1, 2, null]);
        expect(jiao10.floors[0].rooms.map(room => room.name)).toEqual(["教10-101"]);
        expect(jiao10.floors[1].rooms.map(room => room.name)).toEqual(["教10-203"]);
        expect(jiao10.floors[2].rooms.map(room => room.name)).toEqual(["教10-报告厅"]);
    });

    it("楼栋内教室按名称排序", () => {
        const groups = groupRoomsByBuilding(rooms);
        expect(groups[1].rooms.map(room => room.name)).toEqual(["教10-101", "教10-203", "教10-报告厅"]);
        expect(groups[0].rooms.map(room => room.name)).toEqual(["101", "201", "303"]);
    });

    it("整栋都无法识别楼层时只产生“其他教室”组", () => {
        const groups = groupRoomsByBuilding([makeRoom("体育馆", "报告厅")]);
        expect(groups).toHaveLength(1);
        expect(groups[0].floorCount).toBe(0);
        expect(groups[0].unknownFloorCount).toBe(1);
        expect(groups[0].floors.map(group => group.title)).toEqual(["其他教室"]);
    });

    it("空列表返回空数组", () => {
        expect(groupRoomsByBuilding([])).toEqual([]);
    });
});
