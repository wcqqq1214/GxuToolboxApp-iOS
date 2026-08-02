import {useMemo} from "react";
import moment from "moment";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import {useCourse} from "@/features/courseSchedule/hooks/detail/useCourse.ts";
import {useExam} from "@/features/courseSchedule/hooks/detail/useExam.ts";
import {type HolidayRange, useHoliday} from "@/features/courseSchedule/hooks/detail/useHoliday.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import type {Course} from "@/type/infoQuery/course/course.ts";
import type {ExamInfo} from "@/type/infoQuery/exam/examInfo.ts";

const TIME_SPAN_START = [
    "08:00",
    "08:55",
    "10:00",
    "10:55",
    "14:30",
    "15:20",
    "16:25",
    "17:15",
    "18:10",
    "18:45",
    "19:40",
    "20:30",
    "21:20",
];

export type NextEventItem =
    | ScheduleTableItem<Course, "course">
    | ScheduleTableItem<ExamInfo, "exam">
    | ScheduleTableItem<HolidayRange, "holiday">;

export function useNextEvent(): NextEventItem | null {
    const {store: ucStore} = useUserConfig();
    const year = +ucStore(s => s.jw.year);
    const term = ucStore(s => s.jw.term);
    const startDay = useStartDay(year, term);

    const {items: courseItems = []} = useCourse(year, term);
    const {store: examStore} = useExam();
    const examItems = examStore(s => s.examList) || [];
    const holidayItems = useHoliday(year, term) ?? [];

    // 聚合所有日程项
    const allItems: NextEventItem[] = useMemo(
        () => [...courseItems, ...examItems, ...holidayItems] as NextEventItem[],
        [courseItems, examItems, holidayItems],
    );

    return useMemo(() => {
        if (!startDay) return null;

        const now = moment();
        let best: {item: NextEventItem; date: moment.Moment} | null = null;

        for (const item of allItems) {
            const startTime = TIME_SPAN_START[item.begin - 1];
            if (!startTime) continue;

            const [h, m] = startTime.split(":").map(Number);
            const eventDate = startDay
                .clone()
                .add(item.week - 1, "weeks")
                .add(item.day - 1, "days")
                .hour(h)
                .minute(m)
                .second(0);

            if (eventDate.isAfter(now) && (!best || eventDate.isBefore(best.date))) {
                best = {item, date: eventDate};
            }
        }
        return best?.item ?? null;
    }, [allItems, startDay]);
}
