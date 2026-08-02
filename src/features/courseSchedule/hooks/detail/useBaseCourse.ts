import {mmkv} from "@/store/mmkv";
import {ICourse} from "@/features/courseSchedule/type/schema/course.ts";
import {courseApi} from "@/js/jw/course.ts";
import {SchoolTermValue} from "@/type/global.ts";
import {normalizeCourse} from "@/features/courseSchedule/utils/normalizeCourse.ts";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import {Course} from "@/type/infoQuery/course/course.ts";
import {CourseScheduleQueryRes} from "@/type/api/infoQuery/classScheduleAPI.ts";
import {create} from "zustand/react";

interface BaseCourseStoreState {
    rawCourseList: Course[];
    courseList: ScheduleTableItem<Course>[];
    loading: boolean;
}

const useBaseCourseStore = create<BaseCourseStoreState>()(() => {
    // 同步加载MMKV缓存，避免首次渲染空白
    const cached = mmkv.getObject<CourseScheduleQueryRes>("originalCourseList");
    const parsed = cached ? ICourse.safeParse(cached) : undefined;
    if (parsed?.success) {
        return {
            rawCourseList: cached!.kbList,
            courseList: normalizeCourse(parsed.data),
            loading: false,
        };
    }
    return {rawCourseList: [], courseList: [], loading: false};
});

export const useBaseCourse = () => {
    function loadCache(): CourseScheduleQueryRes | undefined {
        return mmkv.getObject<CourseScheduleQueryRes>("originalCourseList");
    }

    function saveCache(data: CourseScheduleQueryRes) {
        mmkv.set("originalCourseList", data);
    }

    async function init(year: number, term: SchoolTermValue) {
        useBaseCourseStore.setState({loading: true});

        const setData = (raw: CourseScheduleQueryRes | null, shouldCache: boolean) => {
            if (!raw) return false;

            const parsed = ICourse.safeParse(raw);
            if (!parsed.success) {
                console.warn("解析原始数据失败", parsed.error);
                return false;
            }

            const newModel = normalizeCourse(parsed.data);

            if (shouldCache) {
                saveCache(raw);
            }
            const current = useBaseCourseStore.getState().courseList;
            if (JSON.stringify(current) === JSON.stringify(newModel)) return true;
            useBaseCourseStore.setState({
                rawCourseList: raw.kbList,
                courseList: newModel,
            });
            return true;
        };

        // 先从MMKV读取缓存快速渲染
        try {
            const cachedRaw = loadCache();
            setData(cachedRaw, false);
        } catch {}

        // 网络请求获取最新数据，成功后覆盖MMKV缓存
        try {
            const classInstance = await courseApi.getCourseSchedule(year, term);
            if (classInstance) {
                setData(classInstance._ori, true);
            }
        } catch (e) {
            console.warn("网络请求失败", e);
        } finally {
            useBaseCourseStore.setState({loading: false});
        }
    }

    return {
        store: useBaseCourseStore,
        init,
        loadCache,
        saveCache,
    };
};
