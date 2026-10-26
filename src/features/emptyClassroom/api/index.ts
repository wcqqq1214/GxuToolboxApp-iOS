import axios from "axios";
import {backendHttp} from "@/features/backend/api";
import {EmptyClassroomDataError, parseBackendEnvelope, parseClassroomPage} from "../schema";
import type {ClassroomItem, ClassroomPage, DayPayload, LogicalTerm, RoomPayload} from "../type";
import {MAX_PAGES, PAGE_SIZE, PAGE_SIZE_FALLBACK, PERIODS} from "../utils/constants";
import {roomKey} from "../utils/roomKey";
import {collectSlotPages} from "./pagination";

/** 单个节次请求的超时（后端代理本身没有显式超时）。 */
const REQUEST_TIMEOUT_MS = 30_000;

/** 网络错误 / 5xx 的最大重试次数。 */
const MAX_TRANSIENT_RETRIES = 2;

/** 瞬时错误重试间隔。 */
const TRANSIENT_RETRY_DELAY_MS = 800;

/** 一次缓存任务内共享的请求上下文；pageSize/authRetried 会被本模块就地更新。 */
export type EmptyClassroomFetchSession = {
    /** 当前有效页大小；旧后端返回 400 后回退到 PAGE_SIZE_FALLBACK。 */
    pageSize: number;
    /** 本任务是否已经为 401/403 触发过重新鉴权，保证每任务最多一次。 */
    authRetried: boolean;
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
 * 作用：为当前任务重新鉴权一次；同任务第二次要求鉴权时直接抛 auth error。
 * 入参：session 为整个缓存任务共享的请求上下文。
 * 出参：无；失败抛 EmptyClassroomAuthError。
 * 修改注意：authRetried 必须在调用 ensureAuth 前置位，防止并发页同时触发多轮重登。
 */
async function reauthenticate(session: EmptyClassroomFetchSession): Promise<void> {
    if (session.authRetried) {
        throw new EmptyClassroomAuthError();
    }
    session.authRetried = true;

    let ok = false;
    try {
        ok = await session.ensureAuth();
    } catch {
        ok = false;
    }
    if (!ok) {
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
 * - session：共享页大小、鉴权重试与取消状态。
 * 出参：Zod 校验后的 ClassroomPage。
 * 修改注意：
 * - 401/403、envelope code 401、data 疑似登录失效都走同一次重登，最多一次；
 * - 旧后端对 pageSize=10000 返回 400 时整个任务回退到 500，且只回退一次；
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

        try {
            const response = await backendHttp.get("/jw/emptyClassroom", {
                params: {
                    weekDay: [range.day],
                    weekList: [range.week],
                    timeList: [period],
                    year: range.year,
                    term: range.term,
                    pageNum,
                    pageSize: session.pageSize,
                },
                paramsSerializer: {indexes: null},
                timeout: REQUEST_TIMEOUT_MS,
            });

            const envelope = parseBackendEnvelope(response.data);
            if (envelope.code === 401) {
                await reauthenticate(session);
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
                    await reauthenticate(session);
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
                await reauthenticate(session);
                continue;
            }
            if (status === 400 && session.pageSize === PAGE_SIZE) {
                session.pageSize = PAGE_SIZE_FALLBACK;
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
 * 作用：顺序抓取一天 13 个节次的空闲教室，并合并为按 roomKey 索引的 DayPayload。
 * 入参：
 * - range：year/term/week/day；
 * - session：共享页大小、鉴权重试与取消状态（store 持有同一个对象）；
 * - onPeriod：每个节次完整抓完后回调，用于进度展示。
 * 出参：DayPayload；中途取消抛 EmptyClassroomCacheCanceledError，鉴权失败抛 EmptyClassroomAuthError。
 * 修改注意：
 * - 每页请求都带 year+term；数组参数必须用重复键序列化（indexes:null）；
 * - 不设置 Accept-Encoding，交给 OkHttp 透明 gzip；
 * - 教室元数据第一份为准；页面数组用完即弃，只保留 Map。
 */
export async function fetchDay(
    range: EmptyClassroomDayRequest,
    session: EmptyClassroomFetchSession,
    onPeriod?: (day: number, period: number) => void,
): Promise<DayPayload> {
    const rooms = new Map<string, RoomPayload>();
    const freePeriods = new Map<string, number[]>();

    for (let period = 1; period <= PERIODS; period += 1) {
        if (session.shouldCancel()) {
            throw new EmptyClassroomCacheCanceledError();
        }

        const page = await collectSlotPages(pageNum => requestPage(range, period, pageNum, session), {
            pageSize: session.pageSize,
            maxPages: MAX_PAGES,
        });

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

        onPeriod?.(range.day, period);
    }

    for (const [key, periods] of freePeriods) {
        freePeriods.set(
            key,
            [...new Set(periods)].sort((left, right) => left - right),
        );
    }

    return {day: range.day, rooms, freePeriods};
}
