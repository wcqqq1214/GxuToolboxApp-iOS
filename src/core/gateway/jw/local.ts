import {http} from "@/core/http";

export const local = {
    async post<T>(url: string, body?: unknown): Promise<T> {
        const res = await http.post<T>(url, body);
        return res.data;
    },

    async get<T>(url: string): Promise<T> {
        const res = await http.get<T>(url);
        return res.data;
    },
};
