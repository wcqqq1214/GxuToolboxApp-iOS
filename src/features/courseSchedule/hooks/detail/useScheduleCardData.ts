import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";
import {usePersonalCourseData} from "@/features/courseSchedule/hooks/detail/usePersonalCourseData.ts";
import {ScheduleScope} from "@/features/courseSchedule/repo/personalSchedule.ts";
import {useMemo} from "react";
import {normalizeCourse} from "@/features/classCourseSchedule/utils/normalizeCourse.ts";
import {buildCourseItems} from "@/features/courseSchedule/utils/buildCourseItems.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {useExamInfo} from "@/features/courseSchedule/hooks/detail/useExamInfo.ts";
import {normalizeExam} from "@/features/courseSchedule/utils/normalizeExam.ts";

/**
 * 在这里把所有的数据收拢，并整合成适宜组件渲染的数据结构
 * @param year
 * @param term
 */
export const useScheduleCardData = (year: number, term: number) => {
    const {account, hydrating} = useJwAccount();

    const scope: ScheduleScope | null =
        account?.username && year > 0 && term ? {username: account.username, year, term} : null;
    const {startDay, ready, year: startYear, term: startTerm} = useStartDay(year, term);
    const termReady = ready && startYear === year && startTerm === term;

    const scheduleQuery = usePersonalCourseData(scope);
    const examQuery = useExamInfo(scope);
    const practiceList = scheduleQuery.schedule?.practiceList;

    const courseItem = useMemo(() => {
        if (!scheduleQuery.schedule) return [];
        const rawCourses = normalizeCourse(scheduleQuery.schedule);
        const exams = examQuery.examInfo && termReady ? normalizeExam(examQuery.examInfo, startDay) : [];
        return buildCourseItems([...rawCourses, ...exams], [], [], termReady ? startDay : null);
    }, [scheduleQuery.schedule, examQuery.examInfo, termReady, startDay]);

    return {courseItem, practiceList, startYear, startTerm, ready, termReady, startDay};
};
