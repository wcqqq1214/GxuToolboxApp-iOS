import {SchoolTermValue} from "@/type/global.ts";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import moment from "moment";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";

export interface HolidayRange {
    title: string;
    from: string; // YYYY-MM-DD
    to: string;
}

export const useHoliday = (year: number, term: SchoolTermValue) => {
    const startDay = useStartDay(year, term);

    const holidays: HolidayRange[] = [
        {title: "清明节", from: "2026-04-04", to: "2026-04-06"},
        {title: "三月三", from: "2026-04-17", to: "2026-04-20"},
        {title: "劳动节", from: "2026-05-01", to: "2026-05-05"},
        {title: "端午节", from: "2026-06-19", to: "2026-06-21"},
    ];

    if (!startDay) return [];

    return holidays.flatMap(h => {
        const start = moment(h.from);
        const end = moment(h.to);
        const days: ScheduleTableItem<HolidayRange>[] = [];

        for (let d = start.clone(); d.isSameOrBefore(end); d.add(1, "day")) {
            const weekDiff = d.diff(moment(startDay), "weeks") + 1;
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
