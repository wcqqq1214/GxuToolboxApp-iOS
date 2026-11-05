import {mmkv} from "@/store/mmkv.ts";
import {electiveProgressSchema, type ElectiveProgress} from "../schema/progress.ts";

const cacheKey = (studentId: string) => `elective-progress:v1:${encodeURIComponent(studentId)}`;

export const electiveProgressRepo = {
    /** 读取按账号隔离的服务端计算快照，损坏或账号不匹配时视为无缓存 */
    get(studentId: string): ElectiveProgress | null {
        const raw = mmkv.getObject<unknown>(cacheKey(studentId));
        const result = electiveProgressSchema.safeParse(raw);
        return result.success && result.data.studentId === studentId ? result.data : null;
    },

    /** 同步保存完整服务端结果，调用方须先确认本轮请求仍然有效 */
    save(studentId: string, progress: ElectiveProgress): void {
        if (progress.studentId !== studentId) throw new Error("校选课结果账号不匹配");
        mmkv.set(cacheKey(studentId), progress);
    },
};
