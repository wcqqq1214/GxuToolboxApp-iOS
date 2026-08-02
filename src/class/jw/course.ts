import {BaseZodClass} from "@/class/class.ts";
import {CourseScheduleQueryRes} from "@/type/api/infoQuery/classScheduleAPI.ts";
import {Course, CourseScheduleSchema, CourseSchema} from "@/type/infoQuery/course/course.ts";
import moment from "moment/moment";
import {CourseScheduleData} from "@/js/jw/course.ts";
import {AttendanceDataClass} from "@/class/auth/attendanceSystem.ts";
import {DeepPartial} from "@/type/global.ts";

/** 课表类，解析后的元数据存储在 `transformed` 中，原始数据存储在 `_ori` 中 */
export class CourseScheduleClass extends BaseZodClass<typeof CourseScheduleSchema, CourseScheduleQueryRes> {
    attendanceData?: AttendanceDataClass;

    constructor(apiRes: DeepPartial<CourseScheduleQueryRes>) {
        super(CourseScheduleSchema, apiRes as CourseScheduleQueryRes);
    }

    set setTermAttendanceData(data: AttendanceDataClass) {
        this.attendanceData = data;
    }

    /**
     * 根据周数获取课表
     * @param week 1-20
     */
    getCourseListByWeek(week: number): CourseClass[][] {
        const res = [[], [], [], [], [], [], []] as CourseClass[][];

        this.transformed.kbList.forEach(course => {
            if (course.getWeeksList.includes(week)) {
                res[course.transformed.weekday].push(course);
            }
        });
        return res;
    }

    /**
     * 获取某一天的课表
     * @param date 目标日期
     * @param startDay 课表开始第一天
     */
    getCourseListByDay(date: moment.MomentInput, startDay: moment.MomentInput): CourseClass[] {
        const dateMoment = moment(date);
        const week = Math.ceil(moment.duration(dateMoment.diff(startDay)).asWeeks()) + 1;
        const weekCourseList = this.getCourseListByWeek(week);
        const weekday = dateMoment.weekday();
        return weekCourseList[weekday > 0 ? weekday - 1 : 6];
    }

    /**
     * 获取某一个课程的所有上课周
     * @param course 目标课程
     */
}

export class CourseClass extends BaseZodClass<typeof CourseSchema, Course> {
    weekPeriod: number[];

    constructor(ori: DeepPartial<Course>) {
        const rawOri = ori instanceof CourseClass ? ori._ori : ori;
        super(CourseSchema, rawOri as Course);
        this.weekPeriod = this.getWeeksList;
    }

    /**
     * 获取该课程打卡有效时间（正常和迟到），返回一个Moment对象数组，分别为起始时间和结束时间
     * @param day 当天日期的Moment对象，默认为当前时间，返回根据这个参数复制两个新的Moment对象，新Moment对象的时间为上课时间，日期不变
     */
    getAttendanceTimeSpan(day: moment.Moment = moment()): [moment.Moment, moment.Moment] {
        const courseSpan = this.transformed.periodCount.split("-").map(num => +num - 1);
        const startTimeSpan = CourseScheduleData.timeSpanList[courseSpan[0]]
            .split("\n")[0]
            .split(":")
            .map(num => +num);
        const startTime = day.clone().hour(startTimeSpan[0]).minute(startTimeSpan[1]).add(-20, "m").second(0);

        const endTimeSpan = CourseScheduleData.timeSpanList[courseSpan[1]]
            .split("\n")[1]
            .split(":")
            .map(num => +num);
        const endTime = day.clone().hour(endTimeSpan[0]).minute(endTimeSpan[1]).second(0);
        return [startTime, endTime];
    }

    get getWeeksList(): number[] {
        const res = new Set<number>();
        this.transformed.weekRange.split(",").forEach(weekSpanStr => {
            const weekSpan = weekSpanStr
                .replace(/[^0-9-]/g, "")
                .split("-")
                .map(weekItem => +weekItem);
            if (weekSpan.length === 1) {
                res.add(weekSpan[0]);
                return;
            }
            const weekList = new Array(weekSpan[1] - weekSpan[0] + 1).fill(weekSpan[0]).map((v, i) => v + i);
            if (!/[单双]/.test(weekSpanStr)) {
                weekList.forEach(v => res.add(v));
            } else {
                weekList.filter(v => v % 2 === (/单/.test(weekSpanStr) ? 1 : 0)).forEach(v => res.add(v));
            }
        });
        return Array.from(res);
    }

    atDay(day: moment.MomentInput, startDay: moment.MomentInput) {
        const dateMoment = moment(day);
        const week = Math.ceil(moment.duration(dateMoment.diff(startDay)).asWeeks()) + 1;
        const weekday = dateMoment.weekday();
        return weekday === this.transformed.weekday && this.getWeeksList.includes(week);
    }

    atDayWithWeek(day: moment.MomentInput, week: number) {
        const dateMoment = moment(day);
        const weekday = dateMoment.weekday();
        return weekday === this.transformed.weekday && this.getWeeksList.includes(week);
    }
}
