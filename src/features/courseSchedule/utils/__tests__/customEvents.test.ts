import moment from "moment";
import type {CustomEvent} from "../../type/customEvent";
import {expandCustomEvents, parseTeachingWeeks} from "../customEvents";
import {layoutScheduleBlocks} from "../layoutScheduleBlocks";
import {timelineEvents} from "../timelineEvents";

const startDay = moment.parseZone("2026-09-07T00:00:00+08:00");
const event: CustomEvent = {
    id: 1,
    title: "实验课",
    location: "西综合",
    teacher: "",
    notes: "",
    year: 2026,
    term: 1,
    weeks: [1, 3, 5],
    weekday: 5,
    begin: 1,
    end: 2,
};

it("校验教学周输入，去重后按周次排序", () => {
    expect(parseTeachingWeeks("3,1-3，5", 20)).toEqual([1, 2, 3, 5]);
    for (const input of ["", "3-1", "0", "21", "1,,2"]) {
        expect(() => parseTeachingWeeks(input, 20)).toThrow();
    }
});

it("按所选节次展开不连续教学周并按学期隔离", () => {
    const items = expandCustomEvents([event], 2026, 1, 20);
    expect(items.map(item => item.week)).toEqual([1, 3, 5]);
    expect(items.every(item => item.begin === 1 && item.end === 2)).toBe(true);
    expect(expandCustomEvents([event], 2026, 2, 20)).toEqual([]);
    expect(expandCustomEvents([event], 2026, 1, 0)).toEqual([]);
});

it("跨来源重叠块分列，首尾共用一节也算重叠，不相交的块恢复全宽", () => {
    const blocks = [
        {begin: 1, end: 3},
        {begin: 3, end: 4},
        {begin: 4, end: 5},
        {begin: 7, end: 8},
    ];
    const layout = layoutScheduleBlocks(blocks);
    expect(layout.map(item => item.columnCount)).toEqual([2, 2, 2, 1]);
    for (const a of layout) {
        for (const b of layout) {
            if (a === b || a.item.end < b.item.begin || b.item.end < a.item.begin) continue;
            expect(a.column).not.toBe(b.column);
        }
    }
});

it("实验课跟随补课，下一项提示使用实际教学周和星期", () => {
    const [item] = expandCustomEvents([event], 2026, 1, 20);
    const rules: [string, string][] = [["2026-09-13", "2026-09-11"]];
    const moved = timelineEvents([{data: [item], needShift: true}], startDay, rules);
    expect(moved).toHaveLength(1);
    expect(moved[0].day).toBe(7);
    expect(moved[0].week).toBe(1);
    expect(moved[0].begin).toBe(item.begin);
});
