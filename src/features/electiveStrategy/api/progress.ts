import {isAxiosError} from "axios";
import {ensureJwAuthenticated} from "@/core/auth/Jw/JwMachine.ts";
import {backendHttp} from "@/features/backend/api";
import type {ApiResponse} from "@/core/type/global.ts";
import {electiveProgressSchema, type ElectiveProgress} from "../schema/progress.ts";

/**
 * 作用：请求当前账号的后端校选课计算结果
 * 入参：studentId 为当前教务账号，signal 用于取消离开页面后的请求
 * 出参：通过结构及账号校验的完整结果，失败时抛错交由 hook 展示
 * 修改注意：此处不调用旧算法，不允许把其他账号的结果写入当前缓存
 */
export async function fetchElectiveProgress(studentId: string, signal?: AbortSignal): Promise<ElectiveProgress> {
    if (!(await ensureJwAuthenticated())) throw new Error("教务系统未登录，请先登录教务账号");
    try {
        const response = await backendHttp.get<ApiResponse<unknown>>("/jw/elective-progress", {timeout: 30000, signal});
        if (response.data?.code !== 200) throw new Error(response.data?.message || "校选课进度获取失败");
        const result = electiveProgressSchema.safeParse(response.data.data);
        if (!result.success) throw new Error("校选课进度数据格式异常，请稍后重试");
        if (result.data.studentId !== studentId) throw new Error("返回结果与当前教务账号不一致，请重新登录");
        return result.data;
    } catch (cause) {
        if (isAxiosError<{message?: string}>(cause) && cause.response?.data?.message) {
            throw new Error(cause.response.data.message);
        }
        throw cause;
    }
}
