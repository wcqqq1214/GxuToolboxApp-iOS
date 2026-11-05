import moment from "moment";
import type {RecordPage} from "@gxutool/adapters/attendance";
import type {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import {getWeekOfDate} from "./weekOfDate.ts";

/**
 * 将学期考勤记录转换为课表匹配项，按实际日期计算教学周、星期，并保留节次和状态。
 * startDay 必须是所选学期的开学日；无效日期、节次及开学前的记录不参与匹配。
 * 返回新数组，不修改记录，也不限制为当前周。
 */
export function normalizeAttendanceRecords(
    records: RecordPage["items"],
    startDay: moment.Moment,
): ScheduleTableItem[] {
    if (!startDay.isValid()) return [];

    return records.flatMap(record => {
        const date = moment(record.date, ["YYYY-MM-DD", "YYYY-M-D"], true);
        if (!date.isValid() || !record.periodRange?.trim()) return [];

        const parts = record.periodRange.split(",").map(part => part.trim());
        if (parts.some(part => !/^\d+$/.test(part))) return [];
        const periods = parts.map(Number);
        const begin = periods[0];
        const end = periods[periods.length - 1];
        if (periods.some(period => period < 1 || period > 13) || end < begin) return [];

        const week = getWeekOfDate(date, startDay);
        if (week < 1) return [];

        return [{
            id: `${date.format("YYYY-MM-DD")}-${begin},${end}`,
            week,
            day: date.isoWeekday() as ScheduleTableItem["day"],
            begin: begin as ScheduleTableItem["begin"],
            end: end as ScheduleTableItem["end"],
            title: record.courseName,
            kind: "attendance",
            status: record.statusCode,
        }];
    });
}
