import {backendHttp} from "@/features/backend/api";
import {
    EmptyClassroomAuthError,
    EmptyClassroomCacheCanceledError,
    fetchDay as fetchDayApi,
    type EmptyClassroomDayRequest,
    type EmptyClassroomFetchSession,
} from "@/features/emptyClassroom/api";
import {runWeekCache, type CacheRunnerDeps} from "@/features/emptyClassroom/services/cacheRunner";
import type {DayPayload, LogicalTerm, RoomPayload} from "@/features/emptyClassroom/type";
import {PAGE_SIZE, PAGE_SIZE_FALLBACK} from "@/features/emptyClassroom/utils/constants";
import {roomKey} from "@/features/emptyClassroom/utils/roomKey";

type DayRequester = (
    request: EmptyClassroomDayRequest,
    session: EmptyClassroomFetchSession,
    onPeriod?: (day: number, period: number) => void,
) => Promise<DayPayload>;

function makePayload(day: number): DayPayload {
    const key = roomKey("教学楼", "R101");
    const room: RoomPayload = {
        key,
        building: "教学楼",
        name: "R101",
        placeType: "普通教室",
        seatCount: 60,
        seatCountForExam: 60,
        owner: "",
        allowToUse: "",
    };
    return {
        day,
        rooms: new Map([[key, room]]),
        freePeriods: new Map([[key, [1, 2]]]),
    };
}

const fetchWholeDay: DayRequester = async (request, _session, onPeriod) => {
    onPeriod?.(request.day, 1);
    return makePayload(request.day);
};

function buildHarness(options: {completed?: number[]; fetchDay?: DayRequester} = {}) {
    const completed = options.completed ?? [];
    const getCompletedDays = jest.fn(
        async (_year: number, _term: LogicalTerm, _week: number) => [...completed],
    );
    const saveDay = jest.fn(
        async (
            _year: number,
            _term: LogicalTerm,
            _week: number,
            _day: number,
            _payload: DayPayload,
        ) => undefined,
    );
    const completeWeek = jest.fn(async (_year: number, _term: LogicalTerm, _week: number) => undefined);
    const fetchDay = jest.fn(options.fetchDay ?? fetchWholeDay);
    const ensureAuth = jest.fn(async () => true);
    const beforeFirstRequest = jest.fn();
    const onProgress = jest.fn();
    const onDaySaved = jest.fn();
    const shouldCancel = jest.fn(() => false);

    const deps: CacheRunnerDeps = {
        repo: {getCompletedDays, saveDay, completeWeek},
        api: {fetchDay},
        ensureAuth,
        beforeFirstRequest,
        onProgress,
        onDaySaved,
        shouldCancel,
    };

    return {
        deps,
        getCompletedDays,
        saveDay,
        completeWeek,
        fetchDay,
        ensureAuth,
        beforeFirstRequest,
        onProgress,
        onDaySaved,
        shouldCancel,
    };
}

const RANGE = {year: 2026, term: 1 as LogicalTerm, week: 3};
const ALL_DAYS = [1, 2, 3, 4, 5, 6, 7];

describe("runWeekCache", () => {
    it("7 天已齐时直接 completeWeek，不鉴权、不发请求", async () => {
        const harness = buildHarness({completed: ALL_DAYS});

        const result = await runWeekCache(RANGE, harness.deps);

        expect(result).toEqual({completedDays: ALL_DAYS, complete: true, canceled: false});
        expect(harness.completeWeek).toHaveBeenCalledTimes(1);
        expect(harness.completeWeek).toHaveBeenCalledWith(RANGE.year, RANGE.term, RANGE.week);
        expect(harness.ensureAuth).not.toHaveBeenCalled();
        expect(harness.beforeFirstRequest).not.toHaveBeenCalled();
        expect(harness.fetchDay).not.toHaveBeenCalled();
        expect(harness.saveDay).not.toHaveBeenCalled();
    });

    it("续传时只抓缺失的天，并最终 completeWeek", async () => {
        const harness = buildHarness({completed: [1, 3, 7]});

        const result = await runWeekCache(RANGE, harness.deps);

        expect(harness.fetchDay.mock.calls.map(call => call[0].day)).toEqual([2, 4, 5, 6]);
        expect(harness.saveDay.mock.calls.map(call => call[3])).toEqual([2, 4, 5, 6]);
        expect(harness.completeWeek).toHaveBeenCalledTimes(1);
        expect(result).toEqual({completedDays: ALL_DAYS, complete: true, canceled: false});
    });

    it("抓了一半的天被取消时不保存该天，已完成的天保留", async () => {
        const harness = buildHarness({
            completed: [1, 2],
            fetchDay: async request => {
                if (request.day === 3) {
                    throw new EmptyClassroomCacheCanceledError();
                }
                return makePayload(request.day);
            },
        });

        const result = await runWeekCache(RANGE, harness.deps);

        expect(result).toEqual({completedDays: [1, 2], complete: false, canceled: true});
        expect(harness.fetchDay).toHaveBeenCalledTimes(1);
        expect(harness.fetchDay.mock.calls[0][0].day).toBe(3);
        expect(harness.saveDay).not.toHaveBeenCalled();
        expect(harness.completeWeek).not.toHaveBeenCalled();
    });

    it("整天抓完后才收到取消时仍然保存该天，然后停止", async () => {
        let canceled = false;
        const harness = buildHarness({
            completed: [1],
            fetchDay: async request => {
                canceled = true;
                return makePayload(request.day);
            },
        });
        harness.shouldCancel.mockImplementation(() => canceled);

        const result = await runWeekCache(RANGE, harness.deps);

        expect(result).toEqual({completedDays: [1, 2], complete: false, canceled: true});
        expect(harness.fetchDay).toHaveBeenCalledTimes(1);
        expect(harness.saveDay).toHaveBeenCalledTimes(1);
        expect(harness.saveDay).toHaveBeenCalledWith(
            RANGE.year,
            RANGE.term,
            RANGE.week,
            2,
            expect.objectContaining({day: 2}),
        );
        expect(harness.onDaySaved).toHaveBeenCalledWith(2, [1, 2]);
        expect(harness.completeWeek).not.toHaveBeenCalled();
    });

    it("任意错误直接抛出，已保存的天保留", async () => {
        const harness = buildHarness({
            completed: [1],
            fetchDay: async request => {
                if (request.day === 3) {
                    throw new Error("接口炸了");
                }
                return makePayload(request.day);
            },
        });

        await expect(runWeekCache(RANGE, harness.deps)).rejects.toThrow("接口炸了");

        expect(harness.saveDay).toHaveBeenCalledTimes(1);
        expect(harness.saveDay.mock.calls[0][3]).toBe(2);
        expect(harness.completeWeek).not.toHaveBeenCalled();
    });

    it("beforeFirstRequest 恰好在第一次数据请求前调用一次", async () => {
        const harness = buildHarness();

        await runWeekCache(RANGE, harness.deps);

        expect(harness.beforeFirstRequest).toHaveBeenCalledTimes(1);
        expect(harness.fetchDay).toHaveBeenCalledTimes(7);
        expect(harness.beforeFirstRequest.mock.invocationCallOrder[0]).toBeLessThan(
            harness.fetchDay.mock.invocationCallOrder[0],
        );
    });

    it("初次鉴权失败抛 auth error，不发请求、不触发 beforeFirstRequest", async () => {
        const harness = buildHarness();
        harness.ensureAuth.mockResolvedValue(false);

        await expect(runWeekCache(RANGE, harness.deps)).rejects.toBeInstanceOf(EmptyClassroomAuthError);

        expect(harness.beforeFirstRequest).not.toHaveBeenCalled();
        expect(harness.fetchDay).not.toHaveBeenCalled();
        expect(harness.saveDay).not.toHaveBeenCalled();
    });

    it("首个缺失天开始前已取消时不发请求、不触发 beforeFirstRequest", async () => {
        const harness = buildHarness({completed: [1]});
        harness.shouldCancel.mockReturnValue(true);

        const result = await runWeekCache(RANGE, harness.deps);

        expect(result).toEqual({completedDays: [1], complete: false, canceled: true});
        expect(harness.fetchDay).not.toHaveBeenCalled();
        expect(harness.beforeFirstRequest).not.toHaveBeenCalled();
    });

    it("每个节次的进度回调带上已完成天", async () => {
        const harness = buildHarness({completed: [1]});

        await runWeekCache(RANGE, harness.deps);

        expect(harness.onProgress).toHaveBeenCalledTimes(6);
        expect(harness.onProgress).toHaveBeenNthCalledWith(1, {
            day: 2,
            period: 1,
            completedDays: [1],
        });
        expect(harness.onProgress).toHaveBeenNthCalledWith(6, {
            day: 7,
            period: 1,
            completedDays: [1, 2, 3, 4, 5, 6],
        });
    });
});

describe("fetchDay 旧后端页大小兼容", () => {
    afterEach(() => {
        jest.restoreAllMocks();
    });

    it("HTTP 400 后全任务回退到 500，且只回退一次", async () => {
        const getSpy = jest.spyOn(backendHttp, "get");
        const badRequest = Object.assign(new Error("Request failed with status code 400"), {
            isAxiosError: true,
            response: {status: 400},
        });
        getSpy.mockRejectedValueOnce(badRequest).mockResolvedValue({
            data: {
                code: 200,
                message: "",
                data: {
                    totalPage: 1,
                    totalCount: 1,
                    items: [{classroomName: "R101", building: "教学楼"}],
                },
            },
        } as Awaited<ReturnType<typeof backendHttp.get>>);

        const session: EmptyClassroomFetchSession = {
            pageSize: PAGE_SIZE,
            authRetried: false,
            ensureAuth: jest.fn(async () => true),
            shouldCancel: jest.fn(() => false),
        };

        const payload = await fetchDayApi({year: 2026, term: 1, week: 3, day: 2}, session);

        expect(getSpy).toHaveBeenCalledTimes(14);
        expect((getSpy.mock.calls[0][1] as {params: {pageSize: number}}).params.pageSize).toBe(PAGE_SIZE);
        expect((getSpy.mock.calls[1][1] as {params: {pageSize: number}}).params.pageSize).toBe(
            PAGE_SIZE_FALLBACK,
        );
        expect((getSpy.mock.calls[13][1] as {params: {pageSize: number}}).params.pageSize).toBe(
            PAGE_SIZE_FALLBACK,
        );
        expect(session.pageSize).toBe(PAGE_SIZE_FALLBACK);

        const key = roomKey("教学楼", "R101");
        expect(payload.rooms.get(key)).toEqual(
            expect.objectContaining({building: "教学楼", name: "R101"}),
        );
        expect(payload.freePeriods.get(key)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]);
    });
});
