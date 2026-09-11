import axios from "axios";
import {backendHttp} from "@/features/backend/api";
import type {BaseInfoRes, DetailTeacherInfo} from "@/features/teachersInfo/type/info.ts";

/** 把请求失败转成可直接展示给用户的错误文案。 */
function toUserMessage(error: unknown): string {
    if (!axios.isAxiosError(error)) return "教师信息加载失败，请稍后重试";

    const status = error.response?.status;
    if (status === undefined) return "网络连接失败，请检查网络后重试";
    if (status === 404) return "未找到该学院的教师信息";
    return "教师信息服务暂时不可用，请稍后重试";
}

async function request<T>(path: string, params: Record<string, string | number>): Promise<T> {
    try {
        const response = await backendHttp.get(path, {params});
        return response.data;
    } catch (error) {
        throw new Error(toUserMessage(error));
    }
}

export const teacherApi = {
    search(keyword: string, page: number = 1): Promise<BaseInfoRes> {
        return request("/teachers/search", {q: keyword, page});
    },

    profile(name: string, school: string): Promise<DetailTeacherInfo> {
        return request("/teachers/profile", {name, school});
    },
};
