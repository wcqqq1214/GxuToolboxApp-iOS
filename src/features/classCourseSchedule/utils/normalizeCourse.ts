import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";

/**
 * normalizeCourse 接受的最小结构契约。
 * 字段名与适配器 Schedule.theoryList 对齐（courseName/weekday/weeks/venueName/qqGroup/sectionRange）。
 */
export interface NormalizableCourse {
    theoryList: Array<{
        courseName: string;
        weekday: number;
        weeks: number[];
        begin: number;
        end: number;
        venueName: string;
        teacher: string;
        qqGroup: string;
        sectionRange: string;
        raw?: any;
    }>;
}

/**
 * 将适配器 Schedule 展开为 UI 使用的 ScheduleTableItem[]（每门课按周次拆成多条）。
 * 仅做字段名适配（适配器 -> ScheduleTableItem），不做数据清洗。
 */
export function normalizeCourse(data: NormalizableCourse): ScheduleTableItem[] {
    const items: ScheduleTableItem[] = [];

    if (!data?.theoryList) return items;

    data.theoryList.forEach(course => {
        course.weeks.forEach(week => {
            items.push({
                id: `${course.courseName}-${week}-${course.weekday}-${course.sectionRange}`,
                week: week,
                day: course.weekday as ScheduleTableItem["day"],
                begin: course.begin as ScheduleTableItem["begin"],
                end: course.end as ScheduleTableItem["end"],
                title: course.courseName,
                location: course.venueName,
                teacher: course.teacher,
                kind: "course",
                raw: course,
                qq: course.qqGroup,
            });
        });
    });

    return items;
}
