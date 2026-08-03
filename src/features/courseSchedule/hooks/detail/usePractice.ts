import {useCallback, useEffect, useState} from "react";
import {store} from "@/core/store.ts";
import {SchoolTermValue} from "@/type/global.ts";
import {classScheduleApi} from "@/features/classCourseSchedule/api";
import type {Schedule} from "gxu-tool-adapters/jw";

export function usePractice(year: number, term: SchoolTermValue): {
    items: Schedule["practiceList"];
    refresh: () => Promise<void>
} {
    const [practiceList, setPracticeList] = useState<Schedule["practiceList"]>([]);

    const fetchPractice = useCallback(async () => {
        const processAndSet = (schedule: Schedule | null, shouldCache: boolean) => {
            if (!schedule) return;

            const newModel = schedule.practiceList;
            setPracticeList(currentModel => {
                if (JSON.stringify(currentModel) === JSON.stringify(newModel)) {
                    return currentModel;
                }
                if (shouldCache) {
                    store.save({key: "practiceSchedule", data: schedule});
                }
                return newModel;
            });
        };

        // 从内存中加载课程缓存
        try {
            const cachedRaw = await store.load<Schedule>({key: "practiceSchedule"}).catch(() => null);
            if (cachedRaw) {
                processAndSet(cachedRaw, false);
            }
        } catch (e) {}

        try {
            const fetchedRaw = await classScheduleApi.fetchPersonalSchedule(year, term);
            if (fetchedRaw) {
                processAndSet(fetchedRaw, true);
            }
        } catch (e) {
            console.warn("网络请求失败", e);
        }
    }, [year, term]);

    useEffect(() => {
        fetchPractice();
    }, [fetchPractice]);

    return {items: practiceList, refresh: fetchPractice};
}
