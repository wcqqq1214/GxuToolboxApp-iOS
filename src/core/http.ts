import axios, {AxiosError} from "axios";

// 默认导出实例
export const http = axios.create({
    baseURL: "https://jwxt2018.gxu.edu.cn/jwglxt",
    headers: {
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    },
    withCredentials: true,
    maxRedirects: 0,
});

http.interceptors.request.use(config => {
    // userMgr.jw
    //     .getAccount()
    //     .then(data => {
    //         if (!data.username || !data.password) {
    //             ToastAndroid.show("未正确设置账号，请前往设置设置账号", ToastAndroid.SHORT);
    //         }
    //     })
    //     .catch(() => {
    //         ToastAndroid.show("未正确设置账号，请前往设置设置账号", ToastAndroid.SHORT);
    //     });

    return config;
});

http.interceptors.response.use(
    response => {
        return response;
    },
    (error: AxiosError) => {
        // 关键：必须返回一个 rejected Promise，以便调用方可以 catch 错误
        return error;
    },
);

export function urlWithParams(url: string, params: Record<string, any> = {}): string {
    Object.keys(params).forEach(key => {
        if (params[key] === undefined) {
            delete params[key];
        }
    });
    return (
        url +
        "?" +
        Object.keys(params)
            .map(key => key + "=" + encodeURIComponent(params[key]))
            .join("&")
    );
}

export function objectToFormUrlEncoded(obj: any): string {
    const parts: string[] = [];

    const buildParams = (prefix: string, value: any) => {
        if (value === undefined || value === null) {
            return;
        }

        if (Array.isArray(value)) {
            value.forEach((v, i) => {
                buildParams(`${prefix}[${i}]`, v);
            });
        } else if (typeof value === "object") {
            Object.keys(value).forEach(key => {
                const newPrefix = prefix ? `${prefix}.${key}` : key;
                buildParams(newPrefix, value[key]);
            });
        } else {
            parts.push(`${prefix}=${encodeURIComponent(value)}`);
        }
    };

    Object.keys(obj).forEach(key => {
        buildParams(key, obj[key]);
    });

    return parts.join("&");
}
