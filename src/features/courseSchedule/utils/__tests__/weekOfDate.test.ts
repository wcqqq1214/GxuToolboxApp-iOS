import {getWeekOfDate} from "@/features/courseSchedule/utils/weekOfDate.ts";

/** 2026-09-07 是周一，作为所有用例的学期第一天 */
const START = "2026-09-07";

describe("getWeekOfDate", () => {
    it("开学当天算第 1 周", () => {
        expect(getWeekOfDate("2026-09-07", START)).toBe(1);
    });

    it("开学当周的周日仍算第 1 周", () => {
        expect(getWeekOfDate("2026-09-13", START)).toBe(1);
    });

    it("第 8 天（下一个周一）算第 2 周 —— ceil 写法在这里会错算成第 1 周", () => {
        expect(getWeekOfDate("2026-09-14", START)).toBe(2);
    });

    it("每个周首日都严格递增，不因跨周而少算", () => {
        const mondays = ["2026-09-07", "2026-09-14", "2026-09-21", "2026-09-28", "2026-10-05"];
        expect(mondays.map(d => getWeekOfDate(d, START))).toEqual([1, 2, 3, 4, 5]);
    });

    it("同一周内 7 天的周数完全相同", () => {
        const week3 = [
            "2026-09-21",
            "2026-09-22",
            "2026-09-23",
            "2026-09-24",
            "2026-09-25",
            "2026-09-26",
            "2026-09-27",
        ];
        expect(week3.map(d => getWeekOfDate(d, START))).toEqual([3, 3, 3, 3, 3, 3, 3]);
    });

    it("startDay 带时分秒时不影响结果（SQLite 链路 toISOString 会带时间）", () => {
        expect(getWeekOfDate("2026-09-14", "2026-09-07T08:00:00")).toBe(2);
        expect(getWeekOfDate("2026-09-14T23:30:00", "2026-09-07T08:00:00")).toBe(2);
    });

    it("目标日期带时分秒时不影响结果", () => {
        expect(getWeekOfDate("2026-09-21T23:59:59", START)).toBe(3);
    });

    it("早于开学日返回 0", () => {
        expect(getWeekOfDate("2026-09-06", START)).toBe(0);
    });

    it("目标日期带时分秒时按「天」归一 —— 不归一的话这天会算成第 1 周", () => {
        // "2026-09-06T23:00:00" 只比开学日 2026-09-07 早 1 小时，但目标侧 startOf("day")
        // 会把它截回 2026-09-06（开学前一天），于是落在学期之前：
        //   归一：  floor(-1 / 7) + 1 = 0
        //   不归一：floor(-1h / 24h) 截断为 0，0 / 7 + 1 = 1
        // 本用例的 0 与 1 之差，唯一地区分了「目标侧是否归一」。
        expect(getWeekOfDate("2026-09-06T23:00:00", START)).toBe(0);
    });

    it("跨月跨年仍连续", () => {
        expect(getWeekOfDate("2027-01-04", START)).toBe(18);
    });
});
