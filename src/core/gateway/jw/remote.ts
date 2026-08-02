import {backendHttp} from "@/features/backend/api";

export const remote = {
    async post<T>(url: string, body?: unknown): Promise<T> {
        const res = await backendHttp.post<T>(url, body);
        return res.data;
    },
};
