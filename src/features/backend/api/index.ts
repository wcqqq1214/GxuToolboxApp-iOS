import axios, {AxiosError} from "axios";

export const backendHttp = axios.create({
    baseURL: "http://api.tool.gxutech.xyz",
    headers: {
        "Content-Type": "application/json",
    },
    withCredentials: true,
    timeout: 10000,
});

backendHttp.interceptors.response.use(
    response => {
        return response;
    },
    (error: AxiosError) => {
        // 关键：必须返回一个 rejected Promise，以便调用方可以 catch 错误
        return Promise.reject(error);
    },
);
