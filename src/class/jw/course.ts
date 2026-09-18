import moment from "moment/moment";
import {CourseScheduleData} from "@/js/jw/course.ts";
import type {Schedule} from "gxu-tool-adapters/jw";
import {AttendanceDataClass} from "@/class/auth/attendanceSystem.ts";

export type AdapterTheoryItem = Schedule['theoryList'][number];

export class CourseScheduleClass {
    schedule: Schedule;
    attendanceData?: AttendanceDataClass;

    constructor(schedule: Schedule) {
        this.schedule = schedule;
    }

    getCourseListByWeek(week: number) {
        return this.schedule.theoryList
            .filter(c => c.weeks.includes(week))
            .reduce((acc, c) => {
                acc[c.weekday - 1].push(c);
                return acc;
            }, [[], [], [], [], [], [], []] as Schedule['theoryList'][]);
    }

    getCourseListByDay(date: moment.MomentInput, startDay: moment.MomentInput) {
        const dateMoment = moment(date);
        const week = Math.ceil(moment.duration(dateMoment.diff(startDay)).asWeeks()) + 1;
        const weekCourseList = this.getCourseListByWeek(week);
        const weekday = dateMoment.weekday();
        return weekCourseList[weekday > 0 ? weekday - 1 : 6];
    }
}

export class CourseClass {
    _ori: AdapterTheoryItem;

    constructor(ori: AdapterTheoryItem | CourseClass) {
        this._ori = ori instanceof CourseClass ? ori._ori : ori;
    }

    getAttendanceTimeSpan(day: moment.Moment = moment()): [moment.Moment, moment.Moment] {
        const courseSpan = (this._ori.sectionRange ?? "1-2").split("-").map(num => +num - 1);
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

    atDay(day: moment.MomentInput, startDay: moment.MomentInput) {
        const dateMoment = moment(day);
        const week = Math.ceil(moment.duration(dateMoment.diff(startDay)).asWeeks()) + 1;
        const weekday = dateMoment.weekday();
        return weekday === this._ori.weekday && (this._ori.weeks ?? []).includes(week);
    }

    atDayWithWeek(day: moment.MomentInput, week: number) {
        const dateMoment = moment(day);
        const weekday = dateMoment.weekday();
        return weekday === this._ori.weekday && (this._ori.weeks ?? []).includes(week);
    }
}
