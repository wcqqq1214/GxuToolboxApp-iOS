import {
    EmptyClassroomAuthError,
    EmptyClassroomCacheCanceledError,
    type EmptyClassroomDayRequest,
    type EmptyClassroomFetchSession,
} from "../api";
import type {DayPayload, LogicalTerm} from "../type";
import {DAYS} from "../utils/constants";

/** 一次缓存任务的范围。 */
export type CacheRunnerRange = {
    year: number;
    term: LogicalTerm;
    week: number;
};

/** 每个节次完成后的进度；completedDays 只包含已落库的天。 */
export type CacheRunnerProgress = {
    day: number;
    period: number;
    completedDays: number[];
};

/** runner 依赖的 repo 子集（便于 Jest 注入 fake）。 */
export type CacheRunnerRepo = {
    getCompletedDays: (year: number, term: LogicalTerm, week: number) => Promise<number[]>;
    saveDay: (year: number, term: LogicalTerm, week: number, day: number, payload: DayPayload) => Promise<void>;
    completeWeek: (year: number, term: LogicalTerm, week: number) => Promise<void>;
};

/** runner 依赖的 API 子集。 */
export type CacheRunnerApi = {
    fetchDay: (
        range: EmptyClassroomDayRequest,
        session: EmptyClassroomFetchSession,
        onPeriod?: (day: number, period: number) => void,
    ) => Promise<DayPayload>;
};

export type CacheRunnerDeps = {
    repo: CacheRunnerRepo;
    api: CacheRunnerApi;
    /** 任务开始时的一次性鉴权；失败抛 EmptyClassroomAuthError。 */
    ensureAuth: () => Promise<boolean>;
    /** 第一次真正发数据请求前调用一次；store 在这里写 lastStartedAt。 */
    beforeFirstRequest: () => void;
    onProgress?: (progress: CacheRunnerProgress) => void;
    onDaySaved?: (day: number, completedDays: number[]) => void;
    shouldCancel: () => boolean;
    /**
     * 可选的共享请求上下文。store 传入同一个对象以共享鉴权与取消状态；
     * 缺省时 runner 自建（供纯测试使用）。
     */
    session?: EmptyClassroomFetchSession;
};

export type CacheRunResult = {
    completedDays: number[];
    complete: boolean;
    canceled: boolean;
};

function normalizeDay(value: number): boolean {
    return Number.isInteger(value) && value >= 1 && value <= DAYS;
}

/**
 * 作用：编排一周 7 天的缓存：续传、鉴权、首次请求标记、逐天保存、取消与完成对账。
 * 入参：
 * - range：year/term/week；
 * - deps：repo/api/鉴权/进度/取消等依赖，便于纯函数测试。
 * 出参：{completedDays, complete, canceled}。
 * 修改注意：
 * - 7 天已齐时只做 completeWeek，不鉴权、不消耗冷却、不发请求；
 * - 抓完一整天后即使已经收到取消也先 saveDay，再停止；
 * - 非取消错误直接抛出，已保存的天保留在 DB。
 */
export async function runWeekCache(range: CacheRunnerRange, deps: CacheRunnerDeps): Promise<CacheRunResult> {
    const initialDays = await deps.repo.getCompletedDays(range.year, range.term, range.week);
    let completedDays = [...new Set(initialDays.filter(normalizeDay))].sort((left, right) => left - right);

    if (completedDays.length === DAYS) {
        await deps.repo.completeWeek(range.year, range.term, range.week);
        return {completedDays, complete: true, canceled: false};
    }

    let authenticated = false;
    try {
        authenticated = await deps.ensureAuth();
    } catch {
        authenticated = false;
    }
    if (!authenticated) {
        throw new EmptyClassroomAuthError();
    }

    const session: EmptyClassroomFetchSession =
        deps.session ??
        ({
            authRetried: false,
            ensureAuth: deps.ensureAuth,
            shouldCancel: deps.shouldCancel,
        } satisfies EmptyClassroomFetchSession);

    let canceled = false;
    let firstDataRequest = true;

    for (let day = 1; day <= DAYS; day += 1) {
        if (completedDays.includes(day)) continue;
        if (deps.shouldCancel()) {
            canceled = true;
            break;
        }

        if (firstDataRequest) {
            firstDataRequest = false;
            deps.beforeFirstRequest();
        }

        let payload: DayPayload;
        try {
            payload = await deps.api.fetchDay({...range, day}, session, (progressDay, period) => {
                deps.onProgress?.({
                    day: progressDay,
                    period,
                    completedDays: [...completedDays],
                });
            });
        } catch (error) {
            if (error instanceof EmptyClassroomCacheCanceledError) {
                canceled = true;
                break;
            }
            throw error;
        }

        // 整天已抓完：即使此刻收到取消也先落库，只丢弃抓了一半的天。
        await deps.repo.saveDay(range.year, range.term, range.week, day, payload);
        completedDays = [...completedDays, day].sort((left, right) => left - right);
        deps.onDaySaved?.(day, [...completedDays]);

        if (deps.shouldCancel()) {
            canceled = true;
            break;
        }
    }

    const complete = completedDays.length === DAYS;
    if (complete) {
        await deps.repo.completeWeek(range.year, range.term, range.week);
    }

    return {completedDays, complete, canceled};
}
