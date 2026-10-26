import {create} from "zustand/react";
import {ensureJwAuthenticated} from "@/core/auth/Jw/JwMachine";
import {mmkv} from "@/store/mmkv";
import {EmptyClassroomAuthError, fetchDay, type EmptyClassroomFetchSession} from "../api";
import {emptyClassroomRepo} from "../repo/EmptyClassroomRepo";
import {runWeekCache} from "../services/cacheRunner";
import type {LogicalTerm} from "../type";
import {COOLDOWN_MS, DAYS, MMKV_LAST_CACHE_STARTED_AT_KEY, PAGE_SIZE} from "../utils/constants";

export type CacheTaskPhase = "auth" | "running" | "canceling";

/** 内存中的当前缓存任务；不持久化，杀 App 后以 day 表为续传真相。 */
export type CacheTask = {
    year: number;
    term: LogicalTerm;
    week: number;
    phase: CacheTaskPhase;
    /** 当前天 1..7；未开始时 0。 */
    day: number;
    /** 当前节次 1..13；未开始时 0。 */
    period: number;
    /** 已落库的天，升序。 */
    completedDays: number[];
    /** 当前任务实际使用的页大小（旧后端会从 10000 回退到 500）。 */
    pageSize: number;
};

export type CacheTaskError = {
    year: number;
    term: LogicalTerm;
    week: number;
    message: string;
};

export type CacheStartResult = {
    ok: boolean;
    reason?: "busy" | "cooldown" | "auth" | "error";
    message?: string;
    remainingMs?: number;
};

export type CacheRunnerState = {
    task: CacheTask | null;
    error: CacheTaskError | null;
    /** 最近一次真正发数据请求的时间，用于跨重启冷却。 */
    lastStartedAt: number;
    /** DB 状态变化计数，供 hooks 重新读取。 */
    revision: number;
    start: (year: number, term: LogicalTerm, week: number) => Promise<CacheStartResult>;
    cancel: () => void;
    clearError: () => void;
};

/** 取消标记；只对当前任务有效。 */
let cancelFlag = false;

/**
 * 同步启动锁。必须在任何 await 之前置位：
 * 双击时两次 start 都可能通过 task 检查，只有同步锁能挡住第二个 runner。
 */
let starting = false;

/** 从 MMKV 恢复冷却时间；损坏值归零，未来时间夹到当前时刻（最多锁一个冷却窗口）。 */
function readLastStartedAt(): number {
    const stored = mmkv.getNumber(MMKV_LAST_CACHE_STARTED_AT_KEY);
    if (stored === undefined || !Number.isFinite(stored) || stored <= 0) return 0;
    const now = Date.now();
    return stored > now ? now : stored;
}

/** 剩余冷却毫秒；lastStartedAt 在未来时按完整窗口处理。 */
function cooldownRemaining(lastStartedAt: number, now: number): number {
    if (!Number.isFinite(lastStartedAt) || lastStartedAt <= 0) return 0;
    const elapsed = now - lastStartedAt;
    if (elapsed >= COOLDOWN_MS) return 0;
    if (elapsed < 0) return COOLDOWN_MS;
    return COOLDOWN_MS - elapsed;
}

function errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
}

export const useCacheRunnerStore = create<CacheRunnerState>((set, get) => ({
    task: null,
    error: null,
    lastStartedAt: readLastStartedAt(),
    revision: 0,

    start: async (year, term, week) => {
        // 同步 busy 检查 + 同步锁，必须在第一次 await 之前完成。
        if (starting || get().task !== null) {
            return {ok: false, reason: "busy"};
        }
        starting = true;
        cancelFlag = false;
        set({error: null});

        try {
            const completedDays = await emptyClassroomRepo.getCompletedDays(year, term, week);

            // 已齐 7 天：只对账，不鉴权、不消耗冷却、不发请求。
            if (completedDays.length === DAYS) {
                await emptyClassroomRepo.completeWeek(year, term, week);
                set(state => ({revision: state.revision + 1}));
                return {ok: true};
            }

            const remainingMs = cooldownRemaining(get().lastStartedAt, Date.now());
            if (remainingMs > 0) {
                return {ok: false, reason: "cooldown", remainingMs};
            }

            // 先同步置 auth phase，双击不会在 await runWeekCache 前留下空窗。
            set({
                error: null,
                task: {
                    year,
                    term,
                    week,
                    phase: "auth",
                    day: 0,
                    period: 0,
                    completedDays,
                    pageSize: PAGE_SIZE,
                },
            });

            const session: EmptyClassroomFetchSession = {
                pageSize: PAGE_SIZE,
                authRetried: false,
                ensureAuth: ensureJwAuthenticated,
                shouldCancel: () => cancelFlag,
            };

            try {
                await runWeekCache(
                    {year, term, week},
                    {
                        repo: {
                            getCompletedDays: emptyClassroomRepo.getCompletedDays,
                            saveDay: emptyClassroomRepo.saveDay,
                            completeWeek: emptyClassroomRepo.completeWeek,
                        },
                        api: {fetchDay},
                        ensureAuth: session.ensureAuth,
                        session,
                        beforeFirstRequest: () => {
                            const startedAt = Date.now();
                            mmkv.set(MMKV_LAST_CACHE_STARTED_AT_KEY, startedAt);
                            set(state => ({
                                lastStartedAt: startedAt,
                                task: state.task ? {...state.task, pageSize: session.pageSize} : state.task,
                            }));
                        },
                        onProgress: progress => {
                            set(state =>
                                state.task
                                    ? {
                                          task: {
                                              ...state.task,
                                              phase: "running",
                                              day: progress.day,
                                              period: progress.period,
                                              completedDays: progress.completedDays,
                                              pageSize: session.pageSize,
                                          },
                                      }
                                    : {},
                            );
                        },
                        onDaySaved: (_day, days) => {
                            set(state => ({
                                task: state.task
                                    ? {...state.task, completedDays: days, pageSize: session.pageSize}
                                    : state.task,
                                revision: state.revision + 1,
                            }));
                        },
                        shouldCancel: () => cancelFlag,
                    },
                );

                return {ok: true};
            } catch (error) {
                if (error instanceof EmptyClassroomAuthError) {
                    // 鉴权失败不写 lastStartedAt；task 在 finally 中清空。
                    return {ok: false, reason: "auth", message: error.message};
                }
                const message = errorMessage(error);
                set({error: {year, term, week, message}});
                return {ok: false, reason: "error", message};
            } finally {
                set(state => ({task: null, revision: state.revision + 1}));
            }
        } catch (error) {
            // getCompletedDays / completeWeek 等 DB 读写失败。
            const message = errorMessage(error);
            set(state => ({
                task: null,
                error: {year, term, week, message},
                revision: state.revision + 1,
            }));
            return {ok: false, reason: "error", message};
        } finally {
            starting = false;
        }
    },

    cancel: () => {
        cancelFlag = true;
        set(state => (state.task ? {task: {...state.task, phase: "canceling"}} : {}));
    },

    clearError: () => set({error: null}),
}));
