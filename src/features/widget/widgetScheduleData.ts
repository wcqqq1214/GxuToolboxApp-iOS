import type {Schedule} from "gxu-tool-adapters/jw";

import {readPersonalSchedule} from "./widgetStore";
import {getStartDay} from "@/features/courseSchedule/stores/startDayStore.ts";

const CLASS_TIMES = [
    ["08:00", "08:45"],
    ["08:55", "09:40"],
    ["10:00", "10:45"],
    ["10:55", "11:40"],
    ["14:30", "15:15"],
    ["15:20", "16:05"],
    ["16:25", "17:10"],
    ["17:15", "18:00"],
    ["18:10", "18:55"],
    ["18:45", "19:30"],
    ["19:40", "20:25"],
    ["20:30", "21:15"],
    ["21:20", "22:05"],
] as const;

export type WidgetDataState = "ready" | "missingSchedule" | "missingStartDay" | "error";

export interface WidgetCourse {
    name: string;
    beginTime: string;
    endTime: string;
    index: string;
    teacher: string;
    room: string;
    date: string;
    startsAt: number;
    endsAt: number;
}

export interface WidgetScheduleData {
    state: WidgetDataState;
    today: WidgetCourse[];
    tomorrow: WidgetCourse[];
    next: WidgetCourse | null;
    nextRefreshAt: number | null;
    refreshedAt: number;
}

function emptyData(state: WidgetDataState, now: Date): WidgetScheduleData {
    return {
        state,
        today: [],
        tomorrow: [],
        next: null,
        nextRefreshAt: null,
        refreshedAt: now.getTime(),
    };
}

function localDate(dateText: string): Date | null {
    const datePart = dateText.slice(0, 10);
    const [year, month, day] = datePart.split("-").map(Number);
    if (!year || !month || !day) return null;

    const date = new Date(year, month - 1, day);
    return Number.isNaN(date.getTime()) ? null : date;
}

function atTime(day: Date, time: string): Date {
    const [hours, minutes] = time.split(":").map(Number);
    const result = new Date(day);
    result.setHours(hours, minutes, 0, 0);
    return result;
}

function dateKey(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
}

function occurrences(schedule: Schedule, termStart: Date): WidgetCourse[] {
    return schedule.theoryList.flatMap(course => {
        const beginTime = CLASS_TIMES[course.begin - 1]?.[0];
        const endTime = CLASS_TIMES[course.end - 1]?.[1];
        if (!beginTime || !endTime || course.weekday < 1 || course.weekday > 7) {
            return [];
        }

        return course.weeks.flatMap(week => {
            if (!Number.isInteger(week) || week < 1) return [];

            const day = new Date(termStart);
            day.setDate(termStart.getDate() + (week - 1) * 7 + course.weekday - 1);
            const starts = atTime(day, beginTime);
            const ends = atTime(day, endTime);

            return [
                {
                    name: course.courseName,
                    beginTime,
                    endTime,
                    index: course.sectionRange,
                    teacher: course.teacher,
                    room: course.venueName,
                    date: dateKey(day),
                    startsAt: starts.getTime(),
                    endsAt: ends.getTime(),
                },
            ];
        });
    });
}

/** 用 personalSchedule 和当前学期 StartDay 生成小组件需要的唯一视图数据。 */
export async function getWidgetSchedule(now = new Date()): Promise<WidgetScheduleData> {
    const schedule = readPersonalSchedule();
    if (!schedule) return emptyData("missingSchedule", now);

    try {
        const startDay = getStartDay();
        const termStart = startDay ? localDate(startDay.day) : null;
        if (!termStart) return emptyData("missingStartDay", now);

        const nowTime = now.getTime();
        const todayKey = dateKey(now);
        const tomorrow = new Date(now);
        tomorrow.setDate(now.getDate() + 1);
        const tomorrowKey = dateKey(tomorrow);
        const courses = occurrences(schedule, termStart).sort((a, b) => a.startsAt - b.startsAt);
        const nextCourseEnd = courses.find(course => course.endsAt > nowTime)?.endsAt;
        const nextDay = new Date(now);
        nextDay.setHours(24, 0, 1, 0);

        return {
            state: "ready",
            today: courses.filter(course => course.date === todayKey && course.endsAt > nowTime),
            tomorrow: courses.filter(course => course.date === tomorrowKey),
            next: courses.find(course => course.startsAt > nowTime) ?? null,
            nextRefreshAt: Math.min(nextCourseEnd ? nextCourseEnd + 1000 : Infinity, nextDay.getTime()),
            refreshedAt: nowTime,
        };
    } catch (error) {
        console.error("[CourseScheduleWidget] Failed to read schedule data", error);
        return emptyData("error", now);
    }
}
