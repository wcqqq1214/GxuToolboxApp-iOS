import type {FreePeriodRow, FreeRunItem} from "../type";
import {DAYS, MAX_WEEKS, PERIODS} from "./constants";

/**
 * 把同一周、同一天内严格相邻的节次合并成连续空闲段。
 * - 只在 period === 上一节 + 1 时合并，不跨天、不对午休做特殊处理；
 * - 输入顺序无关，重复节次只计一次，越界/非法行直接忽略；
 * - ID 由 week/day/begin/end 组成，同一输入始终得到相同结果。
 */
export function buildFreeRuns(rows: readonly FreePeriodRow[]): FreeRunItem[] {
    const sorted = rows
        .filter(
            row =>
                Number.isInteger(row.week) &&
                row.week >= 1 &&
                row.week <= MAX_WEEKS &&
                Number.isInteger(row.day) &&
                row.day >= 1 &&
                row.day <= DAYS &&
                Number.isInteger(row.period) &&
                row.period >= 1 &&
                row.period <= PERIODS,
        )
        .slice()
        .sort((left, right) => left.week - right.week || left.day - right.day || left.period - right.period);

    const runs: FreeRunItem[] = [];
    let current: FreeRunItem | null = null;

    const flush = () => {
        if (!current) return;
        current.id = `${current.week}-${current.day}-${current.begin}-${current.end}`;
        runs.push(current);
        current = null;
    };

    for (const row of sorted) {
        if (current && current.week === row.week && current.day === row.day) {
            if (row.period === current.end) continue;
            if (row.period === current.end + 1) {
                current.end = row.period;
                continue;
            }
        }
        flush();
        current = {
            id: "",
            week: row.week,
            day: row.day,
            begin: row.period,
            end: row.period,
        };
    }
    flush();

    return runs;
}
