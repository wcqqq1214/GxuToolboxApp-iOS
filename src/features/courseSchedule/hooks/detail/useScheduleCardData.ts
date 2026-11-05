import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";
import {usePersonalCourseData} from "@/features/courseSchedule/hooks/detail/usePersonalCourseData.ts";
import {ScheduleScope} from "@/features/courseSchedule/repo/personalSchedule.ts";
import {useCallback, useMemo} from "react";
import {normalizeCourse} from "@/features/classCourseSchedule/utils/normalizeCourse.ts";
import {buildCourseItems} from "@/features/courseSchedule/utils/buildCourseItems.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {useExamInfo} from "@/features/courseSchedule/hooks/detail/useExamInfo.ts";
import {useHoliday} from "@/features/courseSchedule/hooks/detail/useHoliday.ts";
import {normalizeAttendanceRecords} from "@/features/courseSchedule/utils/normalizeAttendanceRecords.ts";
import {useCustomEvents} from "../useCustomEvents";
import {expandCustomEvents} from "../../utils/customEvents";
import {useRecord} from "@/features/attendance/hooks/useRecord.ts";

/**
 * 在这里把所有的数据收拢，并整合成适宜组件渲染的数据结构
 * @param year
 * @param term
 */
export const useScheduleCardData = (year: number, term: number) => {
    const {account, hydrating} = useJwAccount();

    const scope: ScheduleScope | null =
        account?.username && year > 0 && term ? {username: account.username, year, term} : null;
    const {startDay, weekCount, ready, year: startYear, term: startTerm} = useStartDay(year, term);
    const customOwner = hydrating ? null : account?.username ? `jw:${account.username}` : "local";
    const customEvents = useCustomEvents(customOwner);
    const termReady = ready && startYear === year && startTerm === term;
    const customItems = useMemo(
        () => expandCustomEvents(customEvents.events, year, term, termReady ? weekCount : 0),
        [customEvents.events, termReady, year, term, weekCount],
    );
    const holidayItems = useHoliday(startDay, weekCount);

    const scheduleQuery = usePersonalCourseData(scope);
    const examQuery = useExamInfo(scope);
    const {records, refresh: attendanceRefresh, loading: attendanceLoading} = useRecord(scope);
    const practiceList = scheduleQuery.schedule?.practiceList;
    const attendanceItems = useMemo(
        () => termReady ? normalizeAttendanceRecords(records, startDay) : [],
        [records, startDay, termReady],
    );

    const courseItem = useMemo(() => {
        if (!scheduleQuery.schedule) return [];
        const rawCourses = normalizeCourse(scheduleQuery.schedule);
        return buildCourseItems(rawCourses, [], attendanceItems, startDay);
    }, [scheduleQuery.schedule, startDay, attendanceItems]);

    const refresh = useCallback(async () => {
        if (!scope) return;
        await Promise.allSettled([scheduleQuery.refresh(), examQuery.refresh(), attendanceRefresh()]);
    }, [scheduleQuery.refresh, scope, examQuery.refresh, attendanceRefresh]);

    const refreshing = scheduleQuery.status === "loading" || examQuery.status === "loading" || attendanceLoading;

    return {
        courseItem,
        holidayItems,
        examInfo: examQuery.examInfo,
        practiceList,
        startYear,
        startTerm,
        ready,
        startDay,
        refresh,
        refreshing,
        customEvents,
        customItems,
        customOwner,
        weekCount,
        termReady,
    };
};
