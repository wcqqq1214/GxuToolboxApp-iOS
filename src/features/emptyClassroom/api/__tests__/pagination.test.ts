import {collectSlotPages, IncompleteDataError} from "@/features/emptyClassroom/api/pagination.ts";
import type {ClassroomItem, ClassroomPage} from "@/features/emptyClassroom/type/index.ts";

function makeItem(building: string, classroomName: string): ClassroomItem {
    return {
        classroomName,
        placeType: "",
        seatCount: "",
        seatCountForExam: "",
        building,
        owner: "",
        user: "",
        allowToUse: "",
        currentPage: 1,
    };
}

function makePage(items: ClassroomItem[], extra: Omit<Partial<ClassroomPage>, "items"> = {}): ClassroomPage {
    return {
        items,
        currentPage: 1,
        totalPage: extra.totalPage,
        totalCount: extra.totalCount,
        ...extra,
    };
}

function uniqueItems(pageNum: number, count: number): ClassroomItem[] {
    return Array.from({length: count}, (_, index) => makeItem("楼栋", `R${pageNum}-${index}`));
}

async function captureIncomplete(promise: Promise<unknown>): Promise<IncompleteDataError> {
    try {
        await promise;
    } catch (error) {
        expect(error).toBeInstanceOf(IncompleteDataError);
        return error as IncompleteDataError;
    }
    throw new Error("预期抛出 IncompleteDataError 但没有抛出");
}

describe("collectSlotPages", () => {
    it("pageSize=10000 时一页 1690 条即停", async () => {
        const page = makePage(uniqueItems(1, 1690), {
            totalCount: 1690,
            totalPage: 1,
            currentPage: 1,
        });
        const fetchPage = jest.fn(async () => page);

        const result = await collectSlotPages(fetchPage, {pageSize: 10_000, maxPages: 10});

        expect(fetchPage).toHaveBeenCalledTimes(1);
        expect(fetchPage).toHaveBeenCalledWith(1);
        expect(result.pagesFetched).toBe(1);
        expect(result.rawItemCount).toBe(1690);
        expect(result.items).toHaveLength(1690);
        expect(result.totalCount).toBe(1690);
    });

    it("正方强制 500 时按 totalCount 续到 500/500/500/190 四页", async () => {
        const pages = [
            makePage(uniqueItems(1, 500), {totalCount: 1690, totalPage: 4}),
            makePage(uniqueItems(2, 500), {totalCount: 1690, totalPage: 4}),
            makePage(uniqueItems(3, 500), {totalCount: 1690, totalPage: 4}),
            makePage(uniqueItems(4, 190), {totalCount: 1690, totalPage: 4}),
        ];
        // currentPage 恒为 1 也不影响翻页
        const fetchPage = jest.fn(async (pageNum: number) => ({
            ...pages[pageNum - 1],
            currentPage: 1,
        }));

        const result = await collectSlotPages(fetchPage, {pageSize: 500, maxPages: 10});

        expect(fetchPage.mock.calls.map(call => call[0])).toEqual([1, 2, 3, 4]);
        expect(result.pagesFetched).toBe(4);
        expect(result.rawItemCount).toBe(1690);
        expect(result.items).toHaveLength(1690);
    });

    it("不足页不因短页停止，继续按 totalCount 翻页", async () => {
        const pages = [
            makePage(uniqueItems(1, 100), {totalCount: 250}),
            makePage(uniqueItems(2, 150), {totalCount: 250}),
        ];
        const fetchPage = jest.fn(async (pageNum: number) => pages[pageNum - 1]);

        const result = await collectSlotPages(fetchPage, {pageSize: 500, maxPages: 10});

        expect(fetchPage).toHaveBeenCalledTimes(2);
        expect(result.items).toHaveLength(250);
    });

    it("totalCount 不足时抛 IncompleteDataError", async () => {
        const pages = [
            makePage(uniqueItems(1, 500), {totalCount: 1690, totalPage: 5}),
            makePage(uniqueItems(2, 500), {totalCount: 1690, totalPage: 5}),
            makePage(uniqueItems(3, 500), {totalCount: 1690, totalPage: 5}),
            makePage(uniqueItems(4, 100), {totalCount: 1690, totalPage: 5}),
            makePage([], {totalCount: 1690, totalPage: 5}),
        ];
        const fetchPage = jest.fn(async (pageNum: number) => pages[pageNum - 1]);

        const error = await captureIncomplete(collectSlotPages(fetchPage, {pageSize: 500, maxPages: 10}));

        expect(error.collected).toBe(1600);
        expect(error.expected).toBe(1690);
        expect(error.pagesFetched).toBe(5);
        expect(fetchPage).toHaveBeenCalledTimes(5);
    });

    it("翻到 maxPages 上限仍不足时抛错，不静默截断", async () => {
        const fetchPage = jest.fn(async (pageNum: number) =>
            makePage(uniqueItems(pageNum, 500), {totalCount: 1690, totalPage: 4}),
        );

        const error = await captureIncomplete(collectSlotPages(fetchPage, {pageSize: 500, maxPages: 2}));

        expect(error.collected).toBe(1000);
        expect(error.expected).toBe(1690);
        expect(error.pagesFetched).toBe(2);
        expect(fetchPage).toHaveBeenCalledTimes(2);
    });

    it("无 totalCount 时按 totalPage 翻页，短页也不提前停止", async () => {
        const pages = [makePage(uniqueItems(1, 100), {totalPage: 2}), makePage(uniqueItems(2, 120), {totalPage: 2})];
        const fetchPage = jest.fn(async (pageNum: number) => pages[pageNum - 1]);

        const result = await collectSlotPages(fetchPage, {pageSize: 500, maxPages: 10});

        expect(fetchPage).toHaveBeenCalledTimes(2);
        expect(result.items).toHaveLength(220);
        expect(result.totalPage).toBe(2);
    });

    it("totalCount 与 totalPage 都缺省时用短页判定结束", async () => {
        const pages = [makePage(uniqueItems(1, 100)), makePage(uniqueItems(2, 500))];
        const fetchPage = jest.fn(async (pageNum: number) => pages[pageNum - 1]);

        const result = await collectSlotPages(fetchPage, {pageSize: 500, maxPages: 10});

        expect(fetchPage).toHaveBeenCalledTimes(1);
        expect(result.items).toHaveLength(100);
    });

    it("两者都缺省且翻到上限仍为满页时抛错", async () => {
        const fetchPage = jest.fn(async (pageNum: number) => makePage(uniqueItems(pageNum, 2)));

        const error = await captureIncomplete(collectSlotPages(fetchPage, {pageSize: 2, maxPages: 2}));

        expect(error.collected).toBe(4);
        expect(error.pagesFetched).toBe(2);
        expect(fetchPage).toHaveBeenCalledTimes(2);
    });

    it("空页一律停止；totalCount=0 时返回空结果", async () => {
        const fetchPage = jest.fn(async () => makePage([], {totalCount: 0, totalPage: 1}));

        const result = await collectSlotPages(fetchPage, {pageSize: 500, maxPages: 10});

        expect(fetchPage).toHaveBeenCalledTimes(1);
        expect(result.items).toEqual([]);
        expect(result.rawItemCount).toBe(0);
    });

    it("下游按 roomKey 去重，但完整性使用去重前原始行数", async () => {
        const roomA = makeItem("楼栋", "A");
        const roomB = makeItem("楼栋", "B");
        const pages = [makePage([roomA, roomA], {totalCount: 3}), makePage([roomA, roomB], {totalCount: 3})];
        const fetchPage = jest.fn(async (pageNum: number) => pages[pageNum - 1]);

        const result = await collectSlotPages(fetchPage, {pageSize: 500, maxPages: 10});

        expect(fetchPage).toHaveBeenCalledTimes(2);
        expect(result.rawItemCount).toBe(4);
        expect(result.items).toEqual([roomA, roomB]);
    });

    it("拒绝非法 pageSize/maxPages", async () => {
        const fetchPage = jest.fn(async () => makePage([]));

        await expect(collectSlotPages(fetchPage, {pageSize: 0})).rejects.toThrow("pageSize 必须为正整数");
        await expect(collectSlotPages(fetchPage, {maxPages: 0})).rejects.toThrow("maxPages 必须为正整数");
    });
});
