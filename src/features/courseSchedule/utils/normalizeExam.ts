import moment from "moment";
import {getWeekOfDate} from "@/features/courseSchedule/utils/weekOfDate.ts";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";

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

export function normalizeExam(data: ExamWithMeta[], startDay: moment.Moment): ScheduleTableItem<ExamWithMeta>[] {
    const items: ScheduleTableItem<ExamWithMeta>[] = [];

    function timeToTimeSpan(time: string, endTime: boolean = false) {
        let res = -1;
        if (endTime) {
            for (let i = timeSpanList.length - 1; i >= 0; i--) {
                const timeSpanStartTime = timeSpanList[i].split("\n")[0];
                if (moment(timeSpanStartTime, "hh:mm").isBefore(moment(time, "hh:mm"))) {
                    res = i;
                    break;
                }
            }
        } else {
            for (let i = 0; i < timeSpanList.length; i++) {
                const timeSpanEndTime = timeSpanList[i].split("\n")[1];
                if (moment(timeSpanEndTime, "hh:mm").isAfter(moment(time, "hh:mm"))) {
                    res = i;
                    break;
                }
            }
        }
        return (res + 1) as ScheduleTableItem["begin"];
    }

    data.forEach(exam => {
        // 容错：time 不含 (HH:mm-HH:mm) 时跳过该条，避免 undefined.split 抛错。
        const timeRange = exam.time.match(/(?<=\().*?(?=\))/g)?.[0];
        if (!timeRange) return;

        const [begin, end] = timeRange.split("-") as [string, string];
        if (!begin || !end) return;

        const date = moment(exam.time.slice(0, 10));
        items.push({
            day: date.isoWeekday() as ScheduleTableItem["day"],
            title: exam.course,
            id: exam.id,
            week: getWeekOfDate(date, startDay),
            begin: timeToTimeSpan(begin),
            end: timeToTimeSpan(end, true),
            location: exam.classroom,
            seat: exam.seat || "未知",
            kind: "exam",
            raw: exam,
        });
    });

    return items;
}
