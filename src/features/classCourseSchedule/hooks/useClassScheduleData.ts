import {useState} from "react";
import type {Schedule} from "gxu-tool-adapters/jw";
import {classScheduleApi} from "@/features/classCourseSchedule/api";
import {normalizeCourse} from "@/features/classCourseSchedule/utils/normalizeCourse.ts";

export const useClassScheduleData = () => {
    const [theorySchedule, setTheorySchedule] = useState<ReturnType<typeof normalizeCourse> | null>(null);
    const [practiceSchedule, setPracticeSchedule] = useState<Schedule["practiceList"] | null>(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [hasFetched, setHasFetched] = useState(false);

    const applySchedule = (schedule: Schedule) => {
        setTheorySchedule(normalizeCourse(schedule));
        setPracticeSchedule(schedule.practiceList);
    };

    // 直接以用户选的班级 classId 查班级课表，不再先拉教学班列表（class-schedules）
    const fetchSchedule = async (
        year: string | number,
        term: string | number,
        major: string,
        grade: string,
        classId: string,
    ) => {
        setLoading(true);
        setError(null);
        try {
            const res = await classScheduleApi.fetchClassSchedule(String(year), String(term), major, grade, classId);

            // 后端 parseSchedule 解析教务原始数据失败（或教务返回空）时会返回 null。
            // 真正的"无课程"会被解析成空数组而非 null，故 null 视作异常。
            if (res == null) {
                setError("未获取到课表数据，请确认班级与学期或稍后重试");
                setHasFetched(true);
                return;
            }

            applySchedule(res);
            setHasFetched(true);
        } catch (e: any) {
            console.warn("查询班级课表失败", e);
            setError(e?.response?.data?.message || e?.message || "查询失败，请稍后重试");
            setHasFetched(true);
        } finally {
            setLoading(false);
        }
    };

    return {fetchSchedule, theorySchedule, practiceSchedule, loading, error, hasFetched};
};
