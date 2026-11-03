import {ScopedAdapter, useScopedQuery} from "@/features/courseSchedule/hooks/detail/useScopedQuery.ts";
import {ScheduleScope} from "@/features/courseSchedule/repo/personalSchedule.ts";
import {examInfoRepo} from "@/features/examInfo/repo/ExamInfoRepo.ts";
import {getExamInfo} from "@/features/examInfo/api";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";

export const useExamInfo = (scope: ScheduleScope | null) => {
    const adapter: ScopedAdapter<ScheduleScope, ExamWithMeta[]> = {
        fetchRemote: async (s: ScheduleScope) => {
            const res = await getExamInfo(String(s.year), String(s.term));
            if (!res) {
                throw new Error("获取考试信息错误");
            }
            return res;
        },
        getKey: examInfoRepo.examCacheKey,
        readCache: s => examInfoRepo.readCache(s),
        writeCache: (s, data, updatedAt) => examInfoRepo.writeCache(s, data, updatedAt),
    };
    const {data: examInfo, ...rest} = useScopedQuery(scope, adapter);
    return {...rest, examInfo};
};
