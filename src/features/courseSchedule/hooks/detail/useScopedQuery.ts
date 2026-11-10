import {useCallback, useEffect, useMemo, useRef, useState} from "react";

export interface ScopedAdapter<S, T> {
    getKey: (s: S) => string;
    readCache: (s: S) => T | null;
    writeCache: (s: S, data: T, updatedAt: number) => void;
    fetchRemote: (s: S) => Promise<T>;
}

export interface ScopedQuery<T> {
    data: T | null;
    status: "idle" | "error" | "loading" | "success";
    error: string | null;
}

/**
 * 为首页课表设计的通用工厂钩子，传入username和学期信息，以及adapter，即可获得该数据源的{mmkv缓存与同步地获取数据}的能力。
 * adapter中要有1.key规则，2.读缓存和写缓存的函数和3.调远程API的函数
 * @param scope
 * @param adapter
 */
export function useScopedQuery<S, T>(scope: S | null, adapter: ScopedAdapter<S, T>) {
    const key = scope ? adapter.getKey(scope) : null;

    const [queryState, setQueryState] = useState<ScopedQuery<T> & {scopeKey: string | null}>({
        ...{data: null, status: "idle", error: null},
        scopeKey: null,
    });

    const latestRef = useRef({scope, adapter});
    latestRef.current = {scope, adapter};

    const refreshRef = useRef<() => Promise<void>>(async () => {});

    // 渲染期读取缓存，同步且无延迟
    const cachedData = useMemo((): T | null => {
        const currentScope = latestRef.current.scope;
        if (!currentScope || !key) {
            return null;
        }
        try {
            return latestRef.current.adapter.readCache(currentScope);
        } catch (e) {
            console.warn("读取缓存错误", e);
            return null;
        }
    }, [key]);

    useEffect(() => {
        const target = latestRef.current.scope;
        if (!target || !key) return;

        let active = true;
        let latestRequest = 0;

        function update(changes: Partial<ScopedQuery<T>>) {
            setQueryState(current => ({
                data: current.scopeKey === key ? current.data : cachedData,
                status: current.scopeKey === key ? current.status : "loading",
                error: current.scopeKey === key ? current.error : null,
                ...changes,
                scopeKey: key,
            }));
        }

        async function fetchData(isInitial = false): Promise<void> {
            if (!active) return;

            // fetch栅栏，避免换号后旧请求还生效
            const request = ++latestRequest;

            if (!isInitial) {
                update({status: "loading", error: null});
            }

            try {
                const result = await latestRef.current.adapter.fetchRemote(target!);
                if (!active || request !== latestRequest || !target) {
                    return;
                }
                if (!result) {
                    throw new Error("未取得数据，请检查登录状态或后端响应");
                }

                update({data:result, status: "success", error: null});
                try {
                    if (active && request === latestRequest)
                        latestRef.current.adapter.writeCache(target, result, Date.now());
                } catch (cause) {
                    console.warn("课表缓存写入失败", cause);
                }
            } catch (cause) {
                if (!active || request !== latestRequest) return;
                update({status: "error", error: cause instanceof Error ? cause.message : String(cause)});
            }
        }

        refreshRef.current = () => fetchData(false);
        fetchData(true);
        return () => {
            active = false;
            refreshRef.current = async () => {};
        };
    }, [key, cachedData]);

    // 在新 scope 的首帧隐藏旧数据；对象引用变化不会触发重新查询。
    let query: ScopedQuery<T>;
    if (!key) {
        query = {data: null, status: "idle", error: null};
    } else if (queryState.scopeKey === key) {
        query = queryState;
    } else {
        query = {data: cachedData, status: "loading", error: null};
    }

    const refresh = useCallback(() => refreshRef.current(), []);
    return {data: query.data, status: query.status, error: query.error, refresh};
}
