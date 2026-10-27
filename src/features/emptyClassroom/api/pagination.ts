import type {ClassroomItem, ClassroomPage} from "../type";
import {MAX_PAGES, PAGE_SIZE} from "../utils/constants";
import {roomKey} from "../utils/roomKey";

/** 拉取指定页码（1-based）的一页数据。 */
export type FetchClassroomPage = (pageNum: number) => Promise<ClassroomPage>;

export type CollectSlotPagesOptions = {
    /** 本次请求使用的页大小。 */
    pageSize?: number;
    /** 最多翻页数。 */
    maxPages?: number;
};

export type CollectSlotPagesResult = {
    /** 按 roomKey 去重后的教室条目；只用于下游渲染。 */
    items: ClassroomItem[];
    /** 第一页/后续页提供的 totalCount。 */
    totalCount?: number;
    /** 第一页/后续页提供的 totalPage。 */
    totalPage?: number;
    /** 实际请求的页数。 */
    pagesFetched: number;
    /** 去重前的原始行数，用于完整性判断。 */
    rawItemCount: number;
};

/** 数据未达到 totalCount / totalPage 或超过翻页上限时抛出，避免静默缓存截断数据。 */
export class IncompleteDataError extends Error {
    readonly collected: number;
    readonly expected?: number;
    readonly pagesFetched: number;

    constructor(message: string, details: {collected: number; expected?: number; pagesFetched: number}) {
        super(message);
        this.name = "IncompleteDataError";
        this.collected = details.collected;
        this.expected = details.expected;
        this.pagesFetched = details.pagesFetched;
    }
}

/**
 * 顺序翻页取完一个节次的所有空闲教室。
 *
 * 完整性判断优先级：
 * 1. totalCount 存在：只要去重前的累计行数 < totalCount 就继续，即使当前页短于 pageSize
 *    （兼容后端允许 10000、但正方仍按 500 返回的情况）；
 * 2. totalCount 缺省但有 totalPage：翻到 pageNum >= totalPage；
 * 3. 两者都缺省：用短页（items.length < pageSize）判定结束。
 *
 * 空页一律停止；不信任 currentPage。若 totalCount 存在但最终行数不足，或翻到
 * maxPages 上限仍未满足完整性，抛 IncompleteDataError。
 */
export async function collectSlotPages(
    fetchPage: FetchClassroomPage,
    options: CollectSlotPagesOptions = {},
): Promise<CollectSlotPagesResult> {
    const pageSize = options.pageSize ?? PAGE_SIZE;
    const maxPages = options.maxPages ?? MAX_PAGES;
    if (!Number.isInteger(pageSize) || pageSize <= 0) {
        throw new Error(`pageSize 必须为正整数：${pageSize}`);
    }
    if (!Number.isInteger(maxPages) || maxPages <= 0) {
        throw new Error(`maxPages 必须为正整数：${maxPages}`);
    }

    const items: ClassroomItem[] = [];
    const seen = new Set<string>();
    let totalCount: number | undefined;
    let totalPage: number | undefined;
    let pagesFetched = 0;
    let rawItemCount = 0;
    /** 循环是否因为翻页上限而自然结束（没有命中任何结束条件）。 */
    let hitMaxPages = true;

    for (let pageNum = 1; pageNum <= maxPages; pageNum += 1) {
        const page = await fetchPage(pageNum);
        pagesFetched = pageNum;
        if (totalCount === undefined && page.totalCount !== undefined) {
            totalCount = page.totalCount;
        }
        if (totalPage === undefined && page.totalPage !== undefined) {
            totalPage = page.totalPage;
        }

        if (page.items.length === 0) {
            hitMaxPages = false;
            break;
        }
        rawItemCount += page.items.length;
        for (const item of page.items) {
            const key = roomKey(item.building, item.classroomName);
            if (!seen.has(key)) {
                seen.add(key);
                items.push(item);
            }
        }

        if (totalCount !== undefined) {
            if (rawItemCount >= totalCount) {
                hitMaxPages = false;
                break;
            }
            continue;
        }

        if (totalPage !== undefined) {
            if (pagesFetched >= totalPage) {
                hitMaxPages = false;
                break;
            }
            continue;
        }

        if (page.items.length < pageSize) {
            hitMaxPages = false;
            break;
        }
    }

    if (totalCount !== undefined && rawItemCount < totalCount) {
        throw new IncompleteDataError(`空闲教室数据不完整：已取 ${rawItemCount} 条，totalCount=${totalCount}`, {
            collected: rawItemCount,
            expected: totalCount,
            pagesFetched,
        });
    }
    if (hitMaxPages && totalPage !== undefined && pagesFetched < totalPage) {
        throw new IncompleteDataError(`空闲教室翻页超过上限：已取 ${pagesFetched}/${totalPage} 页`, {
            collected: rawItemCount,
            expected: totalCount,
            pagesFetched,
        });
    }
    if (hitMaxPages && totalCount === undefined && totalPage === undefined) {
        throw new IncompleteDataError(`空闲教室翻页超过上限：${maxPages} 页`, {collected: rawItemCount, pagesFetched});
    }

    return {items, totalCount, totalPage, pagesFetched, rawItemCount};
}
