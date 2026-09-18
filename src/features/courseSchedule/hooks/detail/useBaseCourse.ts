import {mmkv} from "@/store/mmkv";
import {SchoolTermValue} from "@/type/global.ts";
import {normalizeCourse} from "@/features/classCourseSchedule/utils/normalizeCourse.ts";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import type {Schedule} from "gxu-tool-adapters/jw";
import {create} from "zustand/react";
import {classScheduleApi} from "@/features/classCourseSchedule/api";

interface BaseCourseStoreState {
    schedule: Schedule | null;
    courseList: ScheduleTableItem[];
    loading: boolean;
}

const useBaseCourseStore = create<BaseCourseStoreState>()(() => {
    const cached = mmkv.getObject<Schedule>("personalSchedule");
    if (cached) {
        return {
            schedule: cached,
            courseList: normalizeCourse(cached),
            loading: false,
        };
    }
    return {schedule: null, courseList: [], loading: false};
});

export const useBaseCourse = () => {
    function loadCache(): Schedule | undefined {
        return mmkv.getObject<Schedule>("personalSchedule");
    }

    function saveCache(data: Schedule) {
        mmkv.set("personalSchedule", data);
    }

    async function init(year: number, term: SchoolTermValue) {
        useBaseCourseStore.setState({loading: true});

        const setData = (schedule: Schedule | null, shouldCache: boolean) => {
            if (!schedule) return false;

            const newModel = normalizeCourse(schedule);

            if (shouldCache) {
                saveCache(schedule);
            }
            const current = useBaseCourseStore.getState().courseList;
            if (JSON.stringify(current) === JSON.stringify(newModel)) return true;
            useBaseCourseStore.setState({
                schedule,
                courseList: newModel,
            });
            return true;
        };

        // 网络请求获取最新数据，成功后覆盖MMKV缓存
        try {
            const schedule = await classScheduleApi.fetchPersonalSchedule(year, term);
            if (schedule) {
                setData(schedule, true);
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
