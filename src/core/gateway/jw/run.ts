import {getJwMode} from "./mode";

/**
 * 调用教务系统接口的网关。
 * @param remote 这个函数需调用后端的接口，再由后端转发。
 * @param local 这个函数用作兜底，直接调用教务系统接口，并在本地解析。
 * @returns
 * */
export async function runJw<T>(remote: () => Promise<T>, local: () => Promise<T>): Promise<T> {
    const mode = getJwMode();

    if (mode === "local_only") return local();
    if (mode === "remote_only") return remote();

    try {
        return await remote();
    } catch (e) {
        if (!canFallback(e)) throw e;
        return local();
    }
}

function canFallback(e: any) {
    const status = e?.response?.status;

    return !e?.response || status === 502 || status === 503 || status === 504;
}
