import {SchoolTermValue} from "@/type/global.ts";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import moment from "moment";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {getWeekOfDate} from "@/features/courseSchedule/utils/weekOfDate.ts";

export interface HolidayRange {
    title: string;
    from: string; // YYYY-MM-DD
    to: string;
}

export const useHoliday = (year: number, term: SchoolTermValue) => {
    const {startDay} = useStartDay(year, term);

    const holidays: HolidayRange[] = [
        {title: "中秋节", from: "2026-09-25", to: "2026-09-27"},
        {title: "国庆节", from: "2026-10-01", to: "2026-10-07"},
        {title: "运动会", from: "2026-11-06", to: "2026-11-08"},
        {title: "元旦", from: "2027-01-01", to: "2027-01-03"},
    ];

    if (!startDay) return [];

    return holidays.flatMap(h => {
        const start = moment(h.from);
        const end = moment(h.to);
        const days: ScheduleTableItem<HolidayRange>[] = [];

        for (let d = start.clone(); d.isSameOrBefore(end); d.add(1, "day")) {
            const weekDiff = getWeekOfDate(d, startDay);
            const dayOfWeek = d.isoWeekday(); // 1=周一, 7=周日

            days.push({
                id: `${h.title}-${d.format("YYYY-MM-DD")}`,
                week: weekDiff,
                day: dayOfWeek as ScheduleTableItem["day"],
                begin: 1, // 占满全天
                end: 13,
                title: d.isSame(start) ? h.title : "",
                subtitle: d.isSame(start) ? "放假" : "",
                kind: "holiday",
            });
        }
        return days;
    });
};
