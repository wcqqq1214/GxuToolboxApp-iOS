import {useCallback, useEffect, useRef, useState} from "react";
import {emptyClassroomRepo, type EmptyClassroomStorageUsage} from "../repo/EmptyClassroomRepo";
import {useCacheRunnerStore} from "../stores/cacheRunnerStore";

export type StorageClearTarget = "rooms" | "weeks";

export type StorageClearResult = {
    ok: boolean;
    reason?: "busy" | "error";
    message?: string;
};

export type EmptyClassroomStorageState = {
    usage: EmptyClassroomStorageUsage | null;
    loading: boolean;
    error: string | null;
    clearing: StorageClearTarget | null;
    refresh: () => void;
    clearRooms: () => Promise<StorageClearResult>;
    clearWeeks: () => Promise<StorageClearResult>;
};

function toMessage(cause: unknown): string {
    return cause instanceof Error ? cause.message : String(cause);
}

/**
 * 作用：管理页的本地存储用量与清理操作。
 * 修改注意：
 * - 统计覆盖数据库中的所有学期；
 * - 清除操作与缓存 runner 共用写队列，但运行中的任务期间直接拒绝；
 * - 操作成功后递增 runner revision，让列表、教室选择器和本 hook 一起重读。
 */
export function useEmptyClassroomStorage(): EmptyClassroomStorageState {
    const revision = useCacheRunnerStore(s => s.revision);
    const [usage, setUsage] = useState<EmptyClassroomStorageUsage | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [clearing, setClearing] = useState<StorageClearTarget | null>(null);
    const [reloadToken, setReloadToken] = useState(0);
    const requestSeq = useRef(0);

    useEffect(() => {
        const seq = requestSeq.current + 1;
        requestSeq.current = seq;
        let active = true;

        setLoading(true);
        emptyClassroomRepo
            .getStorageUsage()
            .then(nextUsage => {
                if (!active || requestSeq.current !== seq) return;
                setUsage(nextUsage);
                setError(null);
            })
            .catch(cause => {
                if (!active || requestSeq.current !== seq) return;
                setError(toMessage(cause));
            })
            .finally(() => {
                if (active && requestSeq.current === seq) setLoading(false);
            });

        return () => {
            active = false;
        };
    }, [revision, reloadToken]);

    const refresh = useCallback(() => setReloadToken(value => value + 1), []);

    const runClear = useCallback(async (target: StorageClearTarget): Promise<StorageClearResult> => {
        if (useCacheRunnerStore.getState().task !== null) {
            return {ok: false, reason: "busy", message: "缓存任务进行中，暂时无法清除数据"};
        }

        setClearing(target);
        try {
            if (target === "rooms") {
                await emptyClassroomRepo.clearAll();
                setUsage({roomsBytes: 0, weeksBytes: 0});
            } else {
                await emptyClassroomRepo.clearWeeks();
                setUsage(current => (current ? {...current, weeksBytes: 0} : current));
            }
            useCacheRunnerStore.getState().invalidate();
            return {ok: true};
        } catch (cause) {
            return {ok: false, reason: "error", message: toMessage(cause)};
        } finally {
            setClearing(null);
        }
    }, []);

    const clearRooms = useCallback(() => runClear("rooms"), [runClear]);
    const clearWeeks = useCallback(() => runClear("weeks"), [runClear]);

    return {
        usage,
        loading,
        error,
        clearing,
        refresh,
        clearRooms,
        clearWeeks,
    };
}
