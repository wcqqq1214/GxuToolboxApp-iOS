import {
    detectFloor,
    groupRoomBuildings,
    groupRoomSearchResults,
    groupRoomsByFloor,
} from "@/features/emptyClassroom/utils/floor.ts";
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

describe("groupRoomBuildings", () => {
    it("只按教室数整理楼栋摘要，并把无法识别的楼栋置顶", () => {
        const groups = groupRoomBuildings([
            {building: "教10", roomCount: 30},
            {building: "", roomCount: 4},
            {building: "教2", roomCount: 20},
        ]);

        expect(groups.map(group => group.title)).toEqual(["其他楼栋", "教2", "教10"]);
        expect(groups.map(group => group.roomCount)).toEqual([4, 20, 30]);
    });

    it("空列表返回空数组", () => {
        expect(groupRoomBuildings([])).toEqual([]);
    });
});

describe("groupRoomsByFloor", () => {
    const jiao10Rooms = [
        makeRoom("教10", "教10-203", 1),
        makeRoom("教10", "教10-101", 2),
        makeRoom("教10", "教10-报告厅", 3),
    ];
    const jiao2Rooms = [makeRoom("教2", "303", 4), makeRoom("教2", "101", 5), makeRoom("教2", "201", 6)];

    it("按楼层数字升序分组", () => {
        const groups = groupRoomsByFloor(jiao2Rooms);
        expect(groups.map(group => group.title)).toEqual(["1 层", "2 层", "3 层"]);
        expect(groups.map(group => group.rooms.length)).toEqual([1, 1, 1]);
    });

    it("无法识别的楼层显示为“其他楼层”并置顶", () => {
        const groups = groupRoomsByFloor(jiao10Rooms);
        expect(groups.map(group => group.title)).toEqual(["其他楼层", "1 层", "2 层"]);
        expect(groups.map(group => group.floor)).toEqual([null, 1, 2]);
        expect(groups[0].rooms.map(room => room.name)).toEqual(["教10-报告厅"]);
    });

    it("组内教室按名称排序", () => {
        expect(groupRoomsByFloor(jiao2Rooms).flatMap(group => group.rooms.map(room => room.name))).toEqual([
            "101",
            "201",
            "303",
        ]);
    });

    it("整栋都无法识别楼层时只产生“其他楼层”组", () => {
        const groups = groupRoomsByFloor([makeRoom("体育馆", "报告厅")]);
        expect(groups).toHaveLength(1);
        expect(groups[0].title).toBe("其他楼层");
        expect(groups[0].rooms).toHaveLength(1);
    });

    it("空列表返回空数组", () => {
        expect(groupRoomsByFloor([])).toEqual([]);
    });
});

describe("groupRoomSearchResults", () => {
    it("按楼栋和楼层生成区域头，并将其他楼栋、其他楼层置顶", () => {
        const sections = groupRoomSearchResults([
            makeRoom("教10", "教10-203", 1),
            makeRoom("教10", "教10-101", 2),
            makeRoom("教10", "教10-报告厅", 3),
            makeRoom("教2", "101", 4),
            makeRoom("", "报告厅", 5),
        ]);

        expect(sections.map(section => section.title)).toEqual([
            "其他楼栋 · 其他楼层",
            "教2 · 1 层",
            "教10 · 其他楼层",
            "教10 · 1 层",
            "教10 · 2 层",
        ]);
        expect(sections[0].rooms.map(room => room.name)).toEqual(["报告厅"]);
    });
});
