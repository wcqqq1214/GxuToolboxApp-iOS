import type {Schedule} from "gxu-tool-adapters/jw";
import {mmkv} from "@/store/mmkv";

export interface ScheduleScope {
    username: string;
    year: number;
    term: number;
}

/** 用账号和逻辑学期定位缓存；不读取无法确认归属的旧全局缓存。 */
export function scheduleCacheKey(scope: ScheduleScope): string {
    return `scheduleData:${encodeURIComponent(scope.username)}:${scope.year}:${scope.term}`;
}

/** 只读写指定账号和学期的快照；读写失败由查询层分别处理。 */
export const personalScheduleRepo = {
    read(scope: ScheduleScope) {
        const cached = mmkv.getObject<{schedule: Schedule; updateAt: number}>(scheduleCacheKey(scope));
        return cached === undefined ? null : cached;
    },
    write(scope: ScheduleScope, schedule: Schedule, updatedAt: number) {
        mmkv.set(scheduleCacheKey(scope), {schedule, updatedAt});
        // 兼容小组件
        mmkv.set("personalSchedule", schedule);
    },
};
