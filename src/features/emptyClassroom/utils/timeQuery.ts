import moment from "moment";
import type {
    AvailableRoomPeriodRow,
    CachedDateOption,
    RoomRecord,
    RoomAvailabilityResult,
    TimeQuerySortDirection,
    TimeQuerySortMode,
} from "../type";
import {DAYS} from "./constants";
import {buildFreeRuns} from "./freeRuns";

const WEEKDAY_LIST = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];

export type RoomAvailabilitySection = {
    key: string;
    title: string;
    data: RoomAvailabilityResult[];
};

function compareName(left: string, right: string): number {
    return left.localeCompare(right, "zh-Hans-CN", {numeric: true});
}

function buildingLabel(building: string): string {
    return building.trim() ? building : "其他楼栋";
}

function compareRoom(left: RoomRecord, right: RoomRecord): number {
    return (
        compareName(buildingLabel(left.building), buildingLabel(right.building)) || compareName(left.name, right.name)
    );
}

/**
 * 作用：把单日、节次范围内的 free-slot 行按教室聚合成时间查询结果。
 * 入参：repo 返回的 room + week/day/period 行。
 * 出参：每间教室一条连续空闲段结果，顺序沿用 SQL 的楼栋/教室顺序。
 * 修改注意：输入节次已在 SQL 中限定范围；这里仍去重并按节次排序，避免脏数据影响合并。
 */
export function buildRoomAvailabilityResults(rows: readonly AvailableRoomPeriodRow[]): RoomAvailabilityResult[] {
    const grouped = new Map<
        number,
        {
            room: RoomRecord;
            week: number;
            day: number;
            periods: Set<number>;
        }
    >();

    for (const row of rows) {
        if (
            !Number.isInteger(row.week) ||
            !Number.isInteger(row.day) ||
            !Number.isInteger(row.period) ||
            row.period < 1
        ) {
            continue;
        }

        const current = grouped.get(row.room.id);
        if (current) {
            current.periods.add(row.period);
        } else {
            grouped.set(row.room.id, {
                room: row.room,
                week: row.week,
                day: row.day,
                periods: new Set([row.period]),
            });
        }
    }

    return [...grouped.values()].map(group => {
        const freeRuns = buildFreeRuns(
            [...group.periods].map(period => ({
                week: group.week,
                day: group.day,
                period,
            })),
        );
        const freePeriodCount = freeRuns.reduce((total, run) => total + run.end - run.begin + 1, 0);
        const longestFreeRun = freeRuns.reduce((longest, run) => Math.max(longest, run.end - run.begin + 1), 0);

        return {
            room: group.room,
            freeRuns,
            freePeriodCount,
            longestFreeRun,
            firstFreePeriod: freeRuns[0]?.begin ?? null,
        };
    });
}

/**
 * 作用：按默认名称或选中范围内的空闲节数排序。
 * 入参：results；mode；direction（default 模式忽略方向）。
 * 出参：新数组，不修改输入。
 * 修改注意：空闲排序同节数时先比较首次空闲节次，再以楼栋/教室名稳定排序。
 */
export function sortRoomAvailabilityResults(
    results: readonly RoomAvailabilityResult[],
    mode: TimeQuerySortMode,
    direction: TimeQuerySortDirection,
): RoomAvailabilityResult[] {
    const factor = direction === "desc" ? -1 : 1;

    return [...results].sort((left, right) => {
        if (mode === "default") return compareRoom(left.room, right.room);

        const countDifference = left.freePeriodCount - right.freePeriodCount;
        if (countDifference !== 0) return countDifference * factor;

        const firstDifference =
            (left.firstFreePeriod ?? Number.MAX_SAFE_INTEGER) - (right.firstFreePeriod ?? Number.MAX_SAFE_INTEGER);
        if (firstDifference !== 0) return firstDifference;

        return compareRoom(left.room, right.room);
    });
}

/**
 * 作用：按楼栋把已排序结果切成 SectionList 分组，空楼栋统一显示为“其他楼栋”。
 * 修改注意：分组顺序沿用结果中首次出现的顺序；同一 section 内保留原排序。
 */
export function groupRoomAvailabilityResults(
    results: readonly RoomAvailabilityResult[],
): RoomAvailabilitySection[] {
    const groups = new Map<string, RoomAvailabilitySection>();

    for (const result of results) {
        const title = buildingLabel(result.room.building);
        const current = groups.get(title);
        if (current) {
            current.data.push(result);
        } else {
            groups.set(title, {key: title, title, data: [result]});
        }
    }

    return [...groups.values()];
}

/**
 * 作用：按选中范围内的空闲节数切分已排序结果，供空闲时间排序展示。
 * 修改注意：分组顺序沿用排序结果中的首次出现顺序；组内顺序由调用方按首次空闲节次和默认顺序排好。
 */
export function groupRoomAvailabilityResultsByFreePeriodCount(
    results: readonly RoomAvailabilityResult[],
): RoomAvailabilitySection[] {
    const groups = new Map<number, RoomAvailabilitySection>();

    for (const result of results) {
        const count = result.freePeriodCount;
        const current = groups.get(count);
        if (current) {
            current.data.push(result);
        } else {
            groups.set(count, {
                key: `free-${count}`,
                title: `空闲 ${count} 节`,
                data: [result],
            });
        }
    }

    return [...groups.values()];
}

/**
 * 作用：根据学期开始日期和教学周生成一周七个日期，并标记实际已缓存的日期。
 * 入参：startDay 为学期第一天；week 为 1-based 教学周；completedDays 为已缓存 ISO 星期。
 * 出参：周一至周日七个选项；非法日期输入返回空数组。
 */
export function buildCachedDateOptions(
    startDay: moment.MomentInput,
    week: number,
    completedDays: readonly number[],
): CachedDateOption[] {
    const start = typeof startDay === "string" ? moment(startDay, moment.ISO_8601, true) : moment(startDay);
    if (!start.isValid() || !Number.isInteger(week) || week < 1) return [];

    const cached = new Set(completedDays.filter(day => Number.isInteger(day) && day >= 1 && day <= DAYS));
    const weekStart = start
        .clone()
        .startOf("day")
        .add((week - 1) * 7, "days");

    return WEEKDAY_LIST.map((weekday, index) => {
        const day = index + 1;
        const date = weekStart.clone().add(index, "days");
        return {
            day,
            weekday,
            dateLabel: date.format("MM-DD"),
            dateKey: date.format("YYYY-MM-DD"),
            cached: cached.has(day),
        };
    });
}
