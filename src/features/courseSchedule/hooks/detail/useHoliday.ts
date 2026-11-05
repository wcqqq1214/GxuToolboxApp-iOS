import type {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import moment, {type Moment} from "moment";
import {useMemo} from "react";
import {getWeekOfDate} from "@/features/courseSchedule/utils/weekOfDate.ts";

export interface HolidayRange {
    title: string;
    from: string; // YYYY-MM-DD
    to: string;
}

const HOLIDAYS: readonly HolidayRange[] = [
    {title: "中秋节", from: "2026-09-25", to: "2026-09-27"},
    {title: "国庆节", from: "2026-10-01", to: "2026-10-07"},
    {title: "运动会", from: "2026-11-06", to: "2026-11-07"},
    {title: "元旦", from: "2027-01-01", to: "2027-01-03"},
];

/** 根据已就绪的开学日和教学周数生成全天节假日项，仅保留落在本学期的日期。 */
export function useHoliday(startDay: Moment | null, weekCount: number) {
    return useMemo(() => {
        if (!startDay?.isValid()) return [];

        return HOLIDAYS.flatMap(holiday => {
            const end = moment(holiday.to);
            const days: ScheduleTableItem<HolidayRange, "holiday">[] = [];

            for (const date = moment(holiday.from); date.isSameOrBefore(end); date.add(1, "day")) {
                const week = getWeekOfDate(date, startDay);
                if (week < 1 || week > weekCount) continue;

                days.push({
                    id: `${holiday.title}-${date.format("YYYY-MM-DD")}`,
                    week,
                    day: date.isoWeekday() as ScheduleTableItem["day"],
                    begin: 1,
                    end: 13,
                    title: holiday.title ,
                    subtitle: "放假",
                    kind: "holiday",
                });
            }
            return days;
        });
    }, [startDay, weekCount]);
}
