import axios from "axios";
import {backendHttp} from "@/features/backend/api";
import {EmptyClassroomDataError, parseBackendEnvelope, parseClassroomPage} from "../schema";
import type {ClassroomItem, ClassroomPage, DayPayload, LogicalTerm, RoomPayload} from "../type";
import {MAX_PAGES, PAGE_SIZE, PERIODS} from "../utils/constants";
import {roomKey} from "../utils/roomKey";
import {collectSlotPages} from "./pagination";

/** 单个节次请求的超时（后端代理本身没有显式超时）。 */
const REQUEST_TIMEOUT_MS = 30_000;

/** 网络错误 / 5xx 的最大重试次数。 */
const MAX_TRANSIENT_RETRIES = 2;

/** 瞬时错误重试间隔。 */
const TRANSIENT_RETRY_DELAY_MS = 800;

/** 一次缓存任务内共享的请求上下文；authRetried/authPromise 会被本模块就地更新。 */
export type EmptyClassroomFetchSession = {
    /** 本任务是否已经为 401/403 触发过重新鉴权，保证每任务最多一次。 */
    authRetried: boolean;
    /**
     * 本任务共享的重登 Promise；13 个节次并发收到 401 时只调用一次 ensureAuth。
     * 由本模块首次需要重登时创建，store 无需设置。
     */
    authPromise?: Promise<boolean>;
    /**
     * 共享重登是否已结束。用于区分「重登前发出的请求」与「重登后仍 401 的请求」：
     * 后者必须直接失败，避免拿同一个成功 Promise 无限重试。由本模块维护。
     */
    authSettled?: boolean;
    /** 重新鉴权；返回是否已登录。 */
    ensureAuth: () => Promise<boolean>;
    /** 用户是否已请求取消。 */
    shouldCancel: () => boolean;
};

/** 单天抓取范围。 */
export type EmptyClassroomDayRequest = {
    year: number;
    term: LogicalTerm;
    week: number;
    day: number;
};

/** 教务鉴权失败（初次鉴权或单次重登失败）；runner/store 据此返回 auth 而非普通 error。 */
export class EmptyClassroomAuthError extends Error {
    constructor(message = "教务登录已失效，请重新登录") {
        super(message);
        this.name = "EmptyClassroomAuthError";
    }
}

/** 用户取消；抓了一半的当天数据由上层丢弃，已保存的天保留。 */
export class EmptyClassroomCacheCanceledError extends Error {
    constructor(message = "空闲教室缓存已取消") {
        super(message);
        this.name = "EmptyClassroomCacheCanceledError";
    }
}

/** 非瞬时、不可重试的接口错误（业务 code 非 200、非回退场景的 400 等）。 */
export class EmptyClassroomRequestError extends Error {
    readonly status?: number;

    constructor(message: string, status?: number) {
        super(message);
        this.name = "EmptyClassroomRequestError";
        this.status = status;
    }
}

function errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
}

function httpStatusOf(error: unknown): number | undefined {
    if (!axios.isAxiosError(error)) return undefined;
    return error.response?.status;
}

function isTransientStatus(status: number): boolean {
    return status >= 500 && status < 600;
}

function delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * 作用：为当前任务重新鉴权一次；同任务后续请求再收到 401 时直接抛 auth error。
 * 入参：
 * - session：整个缓存任务共享的请求上下文；
 * - sentBeforeAuthSettled：本次请求是否在共享重登完成前发出。
 * 出参：无；失败抛 EmptyClassroomAuthError。
 * 修改注意：
 * - 13 个节次并发时可能同时收到 401，所有调用方共享同一个 authPromise，ensureAuth 只调用一次；
 * - 并发请求的 401 即使晚于重登完成才返回，只要请求发出时重登尚未完成，仍可复用结果重试；
 * - 重登完成后发出的请求若仍收到 401，说明重登无效，直接抛错，避免无限重试；
 * - authRetried 必须在创建 authPromise 前置位，防止并发调用创建多轮重登。
 */
async function reauthenticate(session: EmptyClassroomFetchSession, sentBeforeAuthSettled: boolean): Promise<void> {
    if (!session.authPromise) {
        if (session.authRetried) {
            throw new EmptyClassroomAuthError();
        }
        session.authRetried = true;

        const authPromise = (async () => {
            try {
                return await session.ensureAuth();
            } catch {
                return false;
            }
        })();
        session.authPromise = authPromise;
        // 先于所有 await 方注册，确保重登结果落定后才允许后续请求判断「重登后仍 401」。
        authPromise.then(() => {
            session.authSettled = true;
        });
    }

    const ok = await session.authPromise;
    if (!ok || !sentBeforeAuthSettled) {
        throw new EmptyClassroomAuthError();
    }
}

/** 座位数字符串转 number|null；空串/非数字按未知处理。 */
function parseSeatCount(value: string): number | null {
    const text = value.trim();
    if (!text) return null;
    const parsed = Number.parseInt(text, 10);
    return Number.isFinite(parsed) ? parsed : null;
}

/** 单条教室响应转本地稳定模型。 */
function toRoomPayload(item: ClassroomItem, key: string): RoomPayload {
    return {
        key,
        building: item.building.trim(),
        name: item.classroomName.trim(),
        placeType: item.placeType,
        seatCount: parseSeatCount(item.seatCount),
        seatCountForExam: parseSeatCount(item.seatCountForExam),
        owner: item.owner,
        allowToUse: item.allowToUse,
    };
}

/**
 * 作用：请求并解析某个节次的一页空闲教室数据。
 * 入参：
 * - range/period/pageNum：定位请求；
 * - session：共享鉴权重试与取消状态。
 * 出参：Zod 校验后的 ClassroomPage。
 * 修改注意：
 * - 401/403、envelope code 401、data 疑似登录失效都走同一次共享重登，最多一次；
 * - 网络错误/5xx 最多重试 2 次；其他 4xx 不重试。
 */
async function requestPage(
    range: EmptyClassroomDayRequest,
    period: number,
    pageNum: number,
    session: EmptyClassroomFetchSession,
): Promise<ClassroomPage> {
    let transientRetries = 0;

    for (;;) {
        if (session.shouldCancel()) {
            throw new EmptyClassroomCacheCanceledError();
        }

        const sentBeforeAuthSettled = session.authSettled !== true;

        try {
            const response = await backendHttp.get("/jw/emptyClassroom", {
                params: {
                    weekDay: [range.day],
                    weekList: [range.week],
                    timeList: [period],
                    year: range.year,
                    term: range.term,
                    pageNum,
                    pageSize: PAGE_SIZE,
                },
                paramsSerializer: {indexes: null},
                timeout: REQUEST_TIMEOUT_MS,
            });

            const envelope = parseBackendEnvelope(response.data);
            if (envelope.code === 401) {
                await reauthenticate(session, sentBeforeAuthSettled);
                continue;
            }
            if (envelope.code !== 200) {
                throw new EmptyClassroomRequestError(
                    `空闲教室接口返回错误（code=${envelope.code}）：${envelope.message || "未知错误"}`,
                );
            }

            try {
                return parseClassroomPage(envelope.data);
            } catch (error) {
                if (error instanceof EmptyClassroomDataError && error.isLikelyAuthFailure) {
                    await reauthenticate(session, sentBeforeAuthSettled);
                    continue;
                }
                throw error;
            }
        } catch (error) {
            if (
                error instanceof EmptyClassroomCacheCanceledError ||
                error instanceof EmptyClassroomAuthError ||
                error instanceof EmptyClassroomRequestError ||
                error instanceof EmptyClassroomDataError
            ) {
                throw error;
            }

            const status = httpStatusOf(error);
            if (status === 401 || status === 403) {
                await reauthenticate(session, sentBeforeAuthSettled);
                continue;
            }
            if (status !== undefined && !isTransientStatus(status)) {
                throw new EmptyClassroomRequestError(`空闲教室请求失败（HTTP ${status}）`, status);
            }

            if (transientRetries >= MAX_TRANSIENT_RETRIES) {
                throw new EmptyClassroomRequestError(
                    status !== undefined
                        ? `空闲教室请求失败（HTTP ${status}）`
                        : `空闲教室网络请求失败：${errorMessage(error)}`,
                    status,
                );
            }
            transientRetries += 1;
            await delay(TRANSIENT_RETRY_DELAY_MS);
        }
    }
}

/**
 * 作用：并发抓取一天 13 个节次的空闲教室，并合并为按 roomKey 索引的 DayPayload。
 * 入参：
 * - range：year/term/week/day；
 * - session：共享鉴权重试与取消状态（store 持有同一个对象）；
 * - onPeriod：每个节次完整抓完后回调；并发完成顺序不固定，进度可能跳变。
 * 出参：DayPayload；中途取消抛 EmptyClassroomCacheCanceledError，鉴权失败抛 EmptyClassroomAuthError。
 * 修改注意：
 * - 13 个节次同时发出；7 天仍由 runner 顺序执行，总请求数不变；
 * - Promise.all 的结果顺序与输入一致，按节次升序合并，保证 rooms 首份元数据与 freePeriods 确定；
 * - 每页请求都带 year+term；数组参数必须用重复键序列化（indexes:null）；
 * - 不设置 Accept-Encoding，交给 OkHttp 透明 gzip；
 * - 教室元数据第一份为准；页面数组用完即弃，只保留 Map。
 */
export async function fetchDay(
    range: EmptyClassroomDayRequest,
    session: EmptyClassroomFetchSession,
    onPeriod?: (day: number, period: number) => void,
): Promise<DayPayload> {
    if (session.shouldCancel()) {
        throw new EmptyClassroomCacheCanceledError();
    }

    const periodsToFetch = Array.from({length: PERIODS}, (_, index) => index + 1);
    const results = await Promise.all(
        periodsToFetch.map(async period => {
            const page = await collectSlotPages(pageNum => requestPage(range, period, pageNum, session), {
                pageSize: PAGE_SIZE,
                maxPages: MAX_PAGES,
            });
            onPeriod?.(range.day, period);
            return {period, page};
        }),
    );

    const rooms = new Map<string, RoomPayload>();
    const freePeriods = new Map<string, number[]>();

    // 显式按节次升序合并，不依赖完成顺序。
    for (const {period, page} of [...results].sort((left, right) => left.period - right.period)) {
        for (const item of page.items) {
            const building = item.building.trim();
            const name = item.classroomName.trim();
            if (!name) continue;

            const key = roomKey(building, name);
            if (!rooms.has(key)) {
                rooms.set(key, toRoomPayload(item, key));
            }

            const periods = freePeriods.get(key);
            if (periods) {
                if (!periods.includes(period)) {
                    periods.push(period);
                }
            } else {
                freePeriods.set(key, [period]);
            }
        }
    }

    for (const [key, periods] of freePeriods) {
        freePeriods.set(
            key,
            [...new Set(periods)].sort((left, right) => left - right),
        );
    }

    return {day: range.day, rooms, freePeriods};
}
