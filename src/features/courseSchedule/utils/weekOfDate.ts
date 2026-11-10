import moment from "moment";

/**
 * 计算某个日期落在本学期的第几教学周。
 *
 * 作用：把「日期 → 教学周」的口径收敛到一处，替代此前散落在各处、互不兼容的两种写法——
 *   - `Math.ceil(moment.duration(d.diff(startDay)).asWeeks())`：asWeeks() 在整周边界返回整数，
 *     ceil 之后每个周首日（周一）少算一周，开学当天算成第 0 周；
 *   - `d.diff(startDay, "week") + 1`：截断口径正确，但两端未归一，startDay 带时分秒时周首日会被截到上一周。
 *
 * 口径依据：src/type/infoQuery/base.ts 的注释「周数和日期，例：1(2025-02-24至2025-03-02)」，
 * 即第 1 周 = 开学日 .. 开学日 + 6 天。
 *
 * 入参：
 *   - date     目标日期，任意 moment 可解析的输入；内部归一到当天 00:00。
 *   - startDay 学期第一天，任意 moment 可解析的输入；内部归一到当天 00:00。
 *
 * 出参：教学周序号，从 1 开始。开学当天及其后 6 天为第 1 周，之后每满 7 天加 1 周。
 *       日期早于开学日时返回 0 或负数，调用方需自行判断是否需要 clamp。
 *
 * 修改注意：
 *   1. 两端必须先归一到 startOf("day")。startDay 经 SQLite 链路时来自
 *      `termStartDay.day.toISOString()`，在 UTC+8 下会解析成本地 08:00；
 *      不归一的话，周首日会被截断到上一周。
 *   2. 不要改回 Math.ceil(duration.asWeeks())，理由见上方「作用」。
 */
export function getWeekOfDate(date: moment.MomentInput, startDay: moment.MomentInput): number {
    const target = moment(date).startOf("day");
    const termStart = moment(startDay).startOf("day");
    return Math.floor(target.diff(termStart, "days") / 7) + 1;
}
