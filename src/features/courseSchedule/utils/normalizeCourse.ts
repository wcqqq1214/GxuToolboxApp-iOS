import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";

/**
 * normalizeCourse 接受的最小结构契约。
 * 旧的 ICourse（个人课表）和后端 adapter Course 适配后的数据都满足。
 */
export interface NormalizableCourse {
    theoryList: Array<{
        week: number[];
        day: number;
        begin: number;
        end: number;
        title: string;
        location: string;
        teacher: string;
        qq: string;
        index: string;
        raw?: any;
    }>;
}

export function normalizeCourse(data: NormalizableCourse): ScheduleTableItem[] {
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
