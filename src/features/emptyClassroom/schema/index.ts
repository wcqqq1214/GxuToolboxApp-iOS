import {z} from "zod";
import type {EmptyClassroom} from "gxu-tool-adapters/jw";

/** data 为 null / items 非数组时给用户的统一提示（通常是教务登录失效）。 */
export const EMPTY_CLASSROOM_INVALID_RESPONSE_MESSAGE = "教务系统返回异常（登录可能已失效）";

/** API 层可按 isLikelyAuthFailure 决定是否先重试一次鉴权。 */
export class EmptyClassroomDataError extends Error {
    readonly isLikelyAuthFailure: boolean;

    constructor(message: string, isLikelyAuthFailure = false) {
        super(message);
        this.name = "EmptyClassroomDataError";
        this.isLikelyAuthFailure = isLikelyAuthFailure;
    }
}

/** 非 key 字符串缺省补 ""，null 也视为空。 */
const optionalText = z
    .union([z.string(), z.number()])
    .nullish()
    .transform(value => (value === null || value === undefined ? "" : String(value)));

/** 座位数保持字符串；接口给数字时也统一转成字符串。 */
const seatCountText = z
    .union([z.string(), z.number()])
    .nullish()
    .transform(value => (value === null || value === undefined ? "" : String(value)));

/** 分页计数字段；兼容后端把数字序列化成字符串的情况。 */
const optionalCount = z.coerce.number().int().nonnegative().optional();

export const classroomItemSchema = z.object({
    /** 接口必填；空串由 API 层跳过。 */
    classroomName: z.string(),
    placeType: optionalText,
    seatCount: seatCountText,
    seatCountForExam: seatCountText,
    /** 接口必填。 */
    building: z.string(),
    owner: optionalText,
    user: optionalText,
    allowToUse: optionalText,
    /** 正方回显恒为 1，Schema 不信任也不透传，统一归一化。 */
    currentPage: z
        .unknown()
        .optional()
        .transform(() => 1),
});

/**
 * 后端 `data` 的一页空闲教室记录。
 * 未知字段由 zod 默认剥离；分页判断只使用 totalCount/totalPage。
 */
export const classroomPageSchema = z
    .object({
        totalPage: optionalCount,
        totalCount: optionalCount,
        /** 同样不信任上游回显；保留该字段仅为与 adapter 的 EmptyClassroom 类型对齐。 */
        currentPage: z
            .unknown()
            .optional()
            .transform(() => 1),
        items: z.array(classroomItemSchema),
    })
    // adapter 的 EmptyClassroom 把总数字段声明为「必有、可能 undefined」，
    // 这里显式补齐 key，避免输出类型与 adapter 类型不兼容。
    .transform(page => ({
        totalPage: page.totalPage,
        totalCount: page.totalCount,
        currentPage: page.currentPage,
        items: page.items,
    }));

/** 统一信封 `{code, message, data}`；data 留到 parseClassroomPage 再校验。 */
export const backendEnvelopeSchema = z.object({
    code: z.coerce.number(),
    message: z
        .string()
        .nullish()
        .transform(value => value ?? ""),
    data: z.unknown(),
});

export type BackendEnvelope = z.infer<typeof backendEnvelopeSchema>;
export type ClassroomPageData = z.infer<typeof classroomPageSchema>;

/** 校验信封；失败（非 JSON/缺 code）抛普通格式错误。 */
export function parseBackendEnvelope(raw: unknown): BackendEnvelope {
    const result = backendEnvelopeSchema.safeParse(raw);
    if (!result.success) {
        throw new EmptyClassroomDataError(`空闲教室接口响应格式异常：${result.error.message}`);
    }
    return result.data;
}

/**
 * 校验并清洗一页 data，输出与 adapter 的 EmptyClassroom 兼容的结构。
 * data===null 或 items 非数组时不当成空结果，抛出可触发鉴权重试的错误。
 */
export function parseClassroomPage(data: unknown): EmptyClassroom {
    if (data === null || data === undefined) {
        throw new EmptyClassroomDataError(EMPTY_CLASSROOM_INVALID_RESPONSE_MESSAGE, true);
    }
    if (typeof data !== "object" || !Array.isArray((data as {items?: unknown}).items)) {
        throw new EmptyClassroomDataError(EMPTY_CLASSROOM_INVALID_RESPONSE_MESSAGE, true);
    }

    const result = classroomPageSchema.safeParse(data);
    if (!result.success) {
        throw new EmptyClassroomDataError(`空闲教室数据格式异常：${result.error.message}`);
    }
    return result.data;
}

/** 校验信封并取出 data 页。 */
export function parseClassroomEnvelope(raw: unknown): EmptyClassroom {
    return parseClassroomPage(parseBackendEnvelope(raw).data);
}
