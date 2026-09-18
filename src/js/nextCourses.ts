import {store} from "@/core/store.ts";
import {CourseSchema} from "@/type/infoQuery/course/course.ts";
import moment from "moment/moment";
import {loadPersonalSchedule} from "@/features/courseSchedule/cache";

export function parseWeeks(weekStr: string): number[] {
    const result: number[] = [];
    // 按逗号拆成多段
    const segments = weekStr.split(",");

    for (const seg of segments) {
        // 去掉括号、周 字样
        const clean = seg.replace(/周|\(.*?\)/g, "").trim();
        if (!clean) {
            continue;
        }

        if (clean.includes("-")) {
            // 1-3 形式
            const [start, end] = clean.split("-").map(Number);
            const range = Array.from({length: end - start + 1}, (_, i) => start + i);
            // 判断奇偶
            if (seg.includes("(单)")) {
                result.push(...range.filter(n => n % 2 === 1));
            } else if (seg.includes("(双)")) {
                result.push(...range.filter(n => n % 2 === 0));
            } else {
                result.push(...range);
            }
        } else {
            // 单周数字
            const n = Number(clean);
            if (!Number.isNaN(n)) {
                result.push(n);
            }
        }
    }

    // 去重并升序
    return Array.from(new Set(result)).sort((a, b) => a - b);
}

export const nextCourses = async () => {
    const timeSpanList = [
        "08:00\n08:45",
        "08:55\n09:40",
        "10:00\n10:45",
        "10:55\n11:40",
        "14:30\n15:15",
        "15:20\n16:05",
        "16:25\n17:10",
        "17:15\n18:00",
        "18:10\n18:55",
        "18:45\n19:30",
        "19:40\n20:25",
        "20:30\n21:15",
        "21:20\n22:05",
    ];
    const list = loadPersonalSchedule();
    if (!list) {
        return;
    }
    const theoryList = list.theoryList;
    const config = await store.load<any>({key: "userConfig"}).catch(e => {
        console.warn(e);
        return null;
    });
    const startDay = config.jw.startDay;
    const now = moment();
    const tmr = now.clone().add(1, "day");

    const today: any[] = [];
    const tomorrow: any[] = [];
    let next: any = null;
    const startTimes = timeSpanList.map(span => span.split("\n")[0]);
    const endTimes = timeSpanList.map(span => span.split("\n")[1]);
    list.forEach(raw => {
        const result = CourseSchema.safeParse(raw);
        if (!result.success) return;
        const course = result.data;
        const dayOfWeek = course.weekday;
        const startSection = parseInt(course.periodCount.split("-")[0], 10) - 1;
        const endSection = parseInt(course.periodCount.split("-")[1], 10) - 1;
        const courseTime = startTimes[startSection];
        const courseEndTime = endTimes[endSection];
        if (!courseTime) {
            return;
        }

        const [hour, minute] = courseTime.split(":").map(Number);

        parseWeeks(course.weekRange).forEach(week => {
            const courseDate = moment(startDay)
                .add(week - 1, "weeks")
                .day(dayOfWeek)
                .hour(hour)
                .minute(minute)
                .second(0);
            const courseEndDate = moment(startDay)
                .add(week - 1, "weeks")
                .day(dayOfWeek)
                .hour(Number(courseEndTime.split(":")[0]))
                .minute(Number(courseEndTime.split(":")[1]))
                .second(0);

            if (courseDate.isAfter(now)) {
                const courseInfo = {
                    name: course.courseName,
                    beginTime: courseDate.format("HH:mm"),
                    endTime: courseEndDate.format("HH:mm"),
                    index: course.periodCount,
                    teacher: course.name,
                    room: course.venueName,
                    date: courseDate,
                };

                if (!next || courseDate.isBefore(next.date)) {
                    next = courseInfo;
                }
            }

            if (courseDate.isSame(now, "day") && courseDate.isAfter(now)) {
                today.push({
                    name: course.courseName,
                    beginTime: courseDate.format("HH:mm"),
                    endTime: courseEndDate.format("HH:mm"),
                    index: course.periodCount,
                    teacher: course.name,
                    room: course.venueName,
                });
            }
            if (courseDate.isSame(tmr, "day")) {
                tomorrow.push({
                    name: course.courseName,
                    beginTime: courseDate.format("HH:mm"),
                    endTime: courseEndDate.format("HH:mm"),
                    index: course.periodCount,
                    teacher: course.name,
                    room: course.venueName,
                });
            }
        });
    });

    // 从 next 对象中移除临时的 date 字段
    if (next) {
        next.date = next.date.format("YYYY-MM-DD");
    }

    return {today, tomorrow, next};
};
