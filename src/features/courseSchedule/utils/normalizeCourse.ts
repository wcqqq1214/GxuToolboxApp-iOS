import {ICourse} from "@/features/courseSchedule/type/schema/course.ts";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";

export function normalizeCourse(data: ICourse): ScheduleTableItem[] {
    const items: ScheduleTableItem[] = [];

    if (!data?.theoryList) return items;

    data.theoryList.forEach(course => {
        // week is already number[] from Zod
        const weeks = course.week;

        weeks.forEach(week => {
            items.push({
                id: `${course.title}-${week}-${course.day}-${course.index}`,
                week: week,
                day: course.day as ScheduleTableItem['day'],
                begin: course.begin as ScheduleTableItem['begin'],
                end: course.end as ScheduleTableItem['begin'],
                title: course.title,
                location: course.location,
                teacher: course.teacher,
                kind: "course",
                raw: course.raw,
                qq: course.qq,
                // color: undefined,
            });
        });
    });

    return items;
}
