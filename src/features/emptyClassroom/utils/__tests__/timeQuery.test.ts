import moment from "moment";
import type {AvailableRoomPeriodRow, RoomRecord} from "@/features/emptyClassroom/type";
import {
    buildCachedDateOptions,
    buildRoomAvailabilityResults,
    groupRoomAvailabilityResults,
    groupRoomAvailabilityResultsByFreePeriodCount,
    sortRoomAvailabilityResults,
} from "@/features/emptyClassroom/utils/timeQuery.ts";

function room(id: number, building: string, name: string): RoomRecord {
    return {
        id,
        building,
        name,
        placeType: "普通教室",
        seatCount: 60,
        seatCountForExam: 30,
        owner: "",
        allowToUse: "",
        updatedAt: new Date("2026-10-01"),
    };
}

function row(roomRecord: RoomRecord, period: number, day = 2): AvailableRoomPeriodRow {
    return {room: roomRecord, week: 5, day, period};
}

describe("timeQuery", () => {
    test("按教室合并连续空闲段并统计连续长度", () => {
        const roomA = room(1, "教10", "101");
        const roomB = room(2, "教10", "102");

        const results = buildRoomAvailabilityResults([
            row(roomA, 1),
            row(roomA, 2),
            row(roomA, 4),
            row(roomB, 2),
            row(roomB, 3),
            row(roomB, 4),
            row(roomB, 4),
        ]);

        expect(results).toHaveLength(2);
        expect(results[0]).toMatchObject({
            room: {id: 1},
            freePeriodCount: 3,
            longestFreeRun: 2,
            firstFreePeriod: 1,
        });
        expect(results[0].freeRuns).toEqual([
            {id: "5-2-1-2", week: 5, day: 2, begin: 1, end: 2},
            {id: "5-2-4-4", week: 5, day: 2, begin: 4, end: 4},
        ]);
        expect(results[1]).toMatchObject({
            room: {id: 2},
            freePeriodCount: 3,
            longestFreeRun: 3,
        });
    });

    test("默认按楼栋和教室名排序，空闲排序支持正反方向", () => {
        const roomA = room(1, "教2", "101");
        const roomB = room(2, "教10", "101");
        const roomC = room(3, "教10", "102");
        const results = buildRoomAvailabilityResults([
            row(roomA, 1),
            row(roomA, 2),
            row(roomB, 1),
            row(roomB, 2),
            row(roomB, 3),
            row(roomC, 1),
        ]);

        expect(sortRoomAvailabilityResults(results, "default", "desc").map(item => item.room.id)).toEqual([1, 2, 3]);
        expect(sortRoomAvailabilityResults(results, "free", "desc").map(item => item.room.id)).toEqual([2, 1, 3]);
        expect(sortRoomAvailabilityResults(results, "free", "asc").map(item => item.room.id)).toEqual([3, 1, 2]);
    });

    test("空闲时间按节数分组，组内按首次空闲节次和默认顺序排列", () => {
        const results = buildRoomAvailabilityResults([
            row(room(1, "教10", "101"), 1),
            row(room(1, "教10", "101"), 3),
            row(room(2, "教2", "101"), 2),
            row(room(2, "教2", "101"), 3),
            row(room(3, "教1", "101"), 1),
            row(room(3, "教1", "101"), 4),
            row(room(4, "教10", "102"), 1),
            row(room(4, "教10", "102"), 2),
            row(room(4, "教10", "102"), 3),
            row(room(5, "教10", "103"), 5),
        ]);

        const descending = sortRoomAvailabilityResults(results, "free", "desc");
        const ascending = sortRoomAvailabilityResults(results, "free", "asc");
        const descendingSections = groupRoomAvailabilityResultsByFreePeriodCount(descending);
        const ascendingSections = groupRoomAvailabilityResultsByFreePeriodCount(ascending);

        expect(descending.map(item => item.room.id)).toEqual([4, 3, 1, 2, 5]);
        expect(ascending.map(item => item.room.id)).toEqual([5, 3, 1, 2, 4]);
        expect(descendingSections.map(section => section.title)).toEqual(["空闲 3 节", "空闲 2 节", "空闲 1 节"]);
        expect(ascendingSections.map(section => section.title)).toEqual(["空闲 1 节", "空闲 2 节", "空闲 3 节"]);
        expect(descendingSections[1].data.map(item => item.room.id)).toEqual([3, 1, 2]);
    });

    test("按楼栋分组并合并空楼栋，组内保持结果顺序", () => {
        const results = buildRoomAvailabilityResults([
            row(room(3, "", "302"), 1),
            row(room(1, "教10", "102"), 1),
            row(room(2, "", "301"), 1),
            row(room(4, "教10", "101"), 1),
        ]);

        const sections = groupRoomAvailabilityResults(results);

        expect(sections.map(section => section.title)).toEqual(["其他楼栋", "教10"]);
        expect(sections[0].data.map(item => item.room.id)).toEqual([3, 2]);
        expect(sections[1].data.map(item => item.room.id)).toEqual([1, 4]);
    });

    test("生成教学周日期并标记已缓存日期", () => {
        const dates = buildCachedDateOptions("2026-09-07", 2, [2, 4]);

        expect(dates).toHaveLength(7);
        expect(dates[0]).toMatchObject({
            day: 1,
            weekday: "周一",
            dateKey: "2026-09-14",
            cached: false,
        });
        expect(dates[1]).toMatchObject({
            day: 2,
            weekday: "周二",
            dateKey: "2026-09-15",
            cached: true,
        });
    });

    test("日期可以跨越月末，非法输入返回空数组", () => {
        const dates = buildCachedDateOptions(moment("2026-10-26"), 1, [7]);
        expect(dates[6]).toMatchObject({day: 7, dateKey: "2026-11-01", cached: true});
        expect(buildCachedDateOptions("invalid", 1, [])).toEqual([]);
    });
});
