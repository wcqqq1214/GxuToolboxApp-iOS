import type {Schedule} from "gxu-tool-adapters/jw";
import {classScheduleApi} from "@/features/classCourseSchedule/api";
import {
    personalScheduleRepo,
    scheduleCacheKey,
    type ScheduleScope,
} from "@/features/courseSchedule/repo/personalSchedule";
import {ScopedAdapter, useScopedQuery} from "@/features/courseSchedule/hooks/detail/useScopedQuery.ts";
/**
 * 读取指定账号/学期的缓存并查询【个人课表】。null 表示不查询；输入使用逻辑学期 1/2。
 * 每次调用独立持有状态，只有最新请求能提交结果。账号读取和会话归属由认证/API 层负责。
 */
export function usePersonalCourseData(scope: ScheduleScope | null) {
    const adapter: ScopedAdapter<ScheduleScope, Schedule> = {
        getKey: scheduleCacheKey,
        readCache: s => personalScheduleRepo.read(s)?.schedule ?? null,
        writeCache: (s, data, updatedAt) =>
            personalScheduleRepo.write(s, data, updatedAt),
        fetchRemote: async s => {
            const res = await classScheduleApi.fetchPersonalSchedule(s.year, s.term);
            if (!res) {
                throw new Error("获取课表错误");
            }
            return res;
        },
    };
    const u = useScopedQuery(scope, adapter);
    return {...u, schedule: u.data};
}
