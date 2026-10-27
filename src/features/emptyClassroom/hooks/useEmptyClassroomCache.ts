import {useCallback, useEffect, useMemo, useRef, useState} from "react";
import {useFocusEffect} from "@react-navigation/native";
import {emptyClassroomRepo} from "../repo/EmptyClassroomRepo";
import {
    useCacheRunnerStore,
    type CacheStartResult,
    type CacheTask,
    type CacheTaskError,
} from "../stores/cacheRunnerStore";
import type {LogicalTerm, WeekSnapshot} from "../type";
import {useCooldown, type CooldownState} from "./useCooldown";

export type UseEmptyClassroomCacheParams = {
    year: number;
    term: LogicalTerm;
};

export type CacheDeleteResult = {
    ok: boolean;
    reason?: "running" | "error";
    message?: string;
};

export type EmptyClassroomCacheState = {
    /** 该学期所有已缓存周（completedDays>0）。 */
    snapshots: WeekSnapshot[];
    snapshotByWeek: Map<number, WeekSnapshot>;
    /** 当前运行中的任务；可能属于其他学期（缓存页全局 banner 需要）。 */
    task: CacheTask | null;
    /** runner 记录的最近一次失败；可能属于其他学期。 */
    error: CacheTaskError | null;
    loading: boolean;
    /** 本地读取快照失败的提示；runner 错误见 error。 */
    errorMessage: string | null;
    startWeek: (week: number) => Promise<CacheStartResult>;
    deleteWeek: (week: number) => Promise<CacheDeleteResult>;
    cancel: () => void;
    clearError: () => void;
    cooldown: CooldownState;
    reload: () => void;
};

function toMessage(cause: unknown): string {
    return cause instanceof Error ? cause.message : String(cause);
}

function belongsTo(
    task: {year: number; term: LogicalTerm; week: number},
    year: number,
    term: LogicalTerm,
    week: number,
) {
    return task.year === year && task.term === term && task.week === week;
}

/**
 * 作用：缓存管理页数据源；负责快照列表、runner 任务/错误、冷却与单周操作。
 * 入参：year/term（逻辑学期）。
 * 出参：snapshots、snapshotByWeek、task、error、loading、errorMessage、
 *       startWeek、deleteWeek、cancel、clearError、cooldown、reload。
 * 修改注意：
 * - listWeeks 在 focus 和 runner revision 变化时重新读取，本地不再维护第二份快照；
 * - startWeek 只透传 runner 结果，不能把 ok=true 当成「已缓存完成」（7 天已齐也会返回 ok）；
 * - 当前正在运行的周拒绝删除；删除后刷新列表并清掉属于该周的旧 runner 错误。
 */
export function useEmptyClassroomCache(params: UseEmptyClassroomCacheParams): EmptyClassroomCacheState {
    const {year, term} = params;
    const revision = useCacheRunnerStore(s => s.revision);
    const task = useCacheRunnerStore(s => s.task);
    const error = useCacheRunnerStore(s => s.error);
    const lastStartedAt = useCacheRunnerStore(s => s.lastStartedAt);
    const cancel = useCacheRunnerStore(s => s.cancel);
    const clearError = useCacheRunnerStore(s => s.clearError);
    const cooldown = useCooldown(lastStartedAt);

    const [snapshots, setSnapshots] = useState<WeekSnapshot[]>([]);
    const [loading, setLoading] = useState(true);
    const [errorMessage, setErrorMessage] = useState<string | null>(null);
    const [focusToken, setFocusToken] = useState(0);
    const [reloadToken, setReloadToken] = useState(0);

    const requestSeq = useRef(0);
    const focusSeenRef = useRef(false);
    const termKeyRef = useRef("");

    const canLoad = Number.isInteger(year) && year > 0 && (term === 1 || term === 2);
    const termKey = `${year}|${term}`;

    useFocusEffect(
        useCallback(() => {
            if (focusSeenRef.current) setFocusToken(value => value + 1);
            else focusSeenRef.current = true;
        }, []),
    );

    useEffect(() => {
        if (!canLoad) {
            requestSeq.current += 1;
            setSnapshots([]);
            setLoading(false);
            setErrorMessage(null);
            return;
        }

        if (termKeyRef.current !== termKey) {
            termKeyRef.current = termKey;
            setSnapshots([]);
        }

        const seq = requestSeq.current + 1;
        requestSeq.current = seq;
        let active = true;

        setLoading(true);
        setErrorMessage(null);

        emptyClassroomRepo
            .listWeeks(year, term)
            .then(rows => {
                if (!active || requestSeq.current !== seq) return;
                setSnapshots(rows);
            })
            .catch(cause => {
                if (!active || requestSeq.current !== seq) return;
                setErrorMessage(toMessage(cause));
            })
            .finally(() => {
                if (!active || requestSeq.current !== seq) return;
                setLoading(false);
            });

        return () => {
            active = false;
        };
    }, [canLoad, termKey, year, term, revision, focusToken, reloadToken]);

    const snapshotByWeek = useMemo(() => new Map(snapshots.map(snapshot => [snapshot.week, snapshot])), [snapshots]);

    const reload = useCallback(() => setReloadToken(value => value + 1), []);

    const startWeek = useCallback(
        async (week: number): Promise<CacheStartResult> => {
            return useCacheRunnerStore.getState().start(year, term, week);
        },
        [year, term],
    );

    const deleteWeek = useCallback(
        async (week: number): Promise<CacheDeleteResult> => {
            const runner = useCacheRunnerStore.getState();
            if (runner.task && belongsTo(runner.task, year, term, week)) {
                return {ok: false, reason: "running", message: "该周正在缓存，暂时无法删除"};
            }

            try {
                await emptyClassroomRepo.deleteWeek(year, term, week);
            } catch (cause) {
                const message = toMessage(cause);
                setErrorMessage(message);
                return {ok: false, reason: "error", message};
            }

            const latest = useCacheRunnerStore.getState();
            if (latest.error && belongsTo(latest.error, year, term, week)) {
                latest.clearError();
            }
            setReloadToken(value => value + 1);
            return {ok: true};
        },
        [year, term],
    );

    return {
        snapshots,
        snapshotByWeek,
        task,
        error,
        loading,
        errorMessage,
        startWeek,
        deleteWeek,
        cancel,
        clearError,
        cooldown,
        reload,
    };
}
