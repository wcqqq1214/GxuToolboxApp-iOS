import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import {PhyExpParsed} from "@/type/infoQuery/course/course.ts";
import type {Moment} from "moment";

function courseDate(startDay: Moment, item: Pick<ScheduleTableItem, "week" | "day">): string {
    // 距离学期第一天过了多少天：整周 * 7 + 本周第几天 - 1
    const daysFromStart = (item.week - 1) * 7 + (item.day - 1);
    return startDay.clone().startOf("day").add(daysFromStart, "days").format("YYYYMMDD");
}

/**
 * 作用：把理论课方块与物理实验、考勤数据合并成课表最终渲染项。
 * 入参：
 * - courses：normalizeCourse 展开后的理论课；
 * - phyExpList：物理实验列表，按上课日期匹配到标题含“物理实验”的课；
 * - attendanceList：已归一化的考勤项，按 week-day-begin-end 挂载 status；未登录考勤时传 []；
 * - startDay：学期开始日；为 null 时不匹配物理实验。
 * 出参：新数组，不修改任何入参。
 * 修改注意：保持纯函数，不要在这里读 store / mmkv / 鉴权状态。
 */
export const buildCourseItems = (
    courses: readonly ScheduleTableItem[],
    phyExpList: readonly PhyExpParsed[],
    attendanceList: readonly ScheduleTableItem[],
    startDay: Moment | null,
): ScheduleTableItem[] => {
    const phyExpMap = new Map<string, PhyExpParsed>();
    for (const e of phyExpList) {
        phyExpMap.set(e.classDate, e);
    }

    const attendanceMap = new Map<string, ScheduleTableItem>();
    for (const item of attendanceList) {
        const key = `${item.week}-${item.day}-${item.begin}-${item.end}`;
        if (!attendanceMap.has(key)) attendanceMap.set(key, item);
    }

    return courses.map(course => {
        let result = course;

        // 标题里带"物理实验"的课，尝试用实验数据覆盖老师和地点，没传 startDay 就没法算日期，直接跳过
        if (startDay && course.title?.includes("物理实验")) {
            const exp = phyExpMap.get(courseDate(startDay, course));
            if (exp) {
                const teacher = exp.teacherName || exp.teacherFull;
                const location = exp.location || exp.labName;
                result = {
                    ...result,
                    teacher,
                    location,
                };
            }
        }
        const att = attendanceMap.get(`${course.week}-${course.day}-${course.begin}-${course.end}`);
        if (att) {
            result = {...result, status: att.status};
        }

        return result;
    });
};
