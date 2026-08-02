import {backendHttp} from "@/features/backend/api/index.ts";

export const getProfile = async () => {
    const res = await backendHttp.post("/jw/profile", {
        isFull: false,
    });

    // TODO: 检查返回值

    return res.data.data;
};
