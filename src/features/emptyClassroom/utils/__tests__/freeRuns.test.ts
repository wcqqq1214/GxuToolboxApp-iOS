import {buildFreeRuns} from "@/features/emptyClassroom/utils/freeRuns.ts";

const run = (week: number, day: number, begin: number, end: number) => ({
    id: `${week}-${day}-${begin}-${end}`,
    week,
    day,
    begin,
    end,
});

describe("buildFreeRuns", () => {
    it("合并严格相邻的节次", () => {
        expect(
            buildFreeRuns([
                {week: 1, day: 1, period: 1},
                {week: 1, day: 1, period: 2},
                {week: 1, day: 1, period: 3},
            ]),
        ).toEqual([run(1, 1, 1, 3)]);
    });

    it("断点拆成多段", () => {
        expect(
            buildFreeRuns([
                {week: 1, day: 1, period: 1},
                {week: 1, day: 1, period: 2},
                {week: 1, day: 1, period: 5},
                {week: 1, day: 1, period: 7},
                {week: 1, day: 1, period: 8},
            ]),
        ).toEqual([run(1, 1, 1, 2), run(1, 1, 5, 5), run(1, 1, 7, 8)]);
    });

    it("单节保持为单节", () => {
        expect(buildFreeRuns([{week: 3, day: 5, period: 9}])).toEqual([run(3, 5, 9, 9)]);
    });

    it("不跨天合并（day 13 节与次日 1 节分开）", () => {
        expect(
            buildFreeRuns([
                {week: 2, day: 1, period: 13},
                {week: 2, day: 2, period: 1},
            ]),
        ).toEqual([run(2, 1, 13, 13), run(2, 2, 1, 1)]);
    });

    it("不跨周合并", () => {
        expect(
            buildFreeRuns([
                {week: 2, day: 7, period: 13},
                {week: 3, day: 1, period: 1},
            ]),
        ).toEqual([run(2, 7, 13, 13), run(3, 1, 1, 1)]);
    });

    it("输入顺序无关，输出按周/天/节次排序", () => {
        const rows = [
            {week: 3, day: 2, period: 4},
            {week: 1, day: 2, period: 2},
            {week: 3, day: 2, period: 3},
            {week: 1, day: 1, period: 1},
        ];
        const expected = [run(1, 1, 1, 1), run(1, 2, 2, 2), run(3, 2, 3, 4)];

        expect(buildFreeRuns(rows)).toEqual(expected);
        expect(buildFreeRuns(rows.slice().reverse())).toEqual(expected);
    });

    it("重复节次只计一次", () => {
        expect(
            buildFreeRuns([
                {week: 1, day: 1, period: 1},
                {week: 1, day: 1, period: 1},
                {week: 1, day: 1, period: 2},
            ]),
        ).toEqual([run(1, 1, 1, 2)]);
    });

    it("同一输入始终生成相同 ID", () => {
        const first = buildFreeRuns([{week: 4, day: 6, period: 10}]);
        const second = buildFreeRuns([{week: 4, day: 6, period: 10}]);
        expect(first).toEqual(second);
        expect(first[0].id).toBe("4-6-10-10");
    });

    it("空输入返回空数组", () => {
        expect(buildFreeRuns([])).toEqual([]);
    });

    it("忽略非法节次与非法周/天", () => {
        expect(
            buildFreeRuns([
                {week: 0, day: 1, period: 1},
                {week: 1, day: 0, period: 1},
                {week: 1, day: 1, period: 0},
                {week: 1, day: 1, period: 1.5},
                {week: 1, day: 1, period: 2},
            ]),
        ).toEqual([run(1, 1, 2, 2)]);
    });
});
