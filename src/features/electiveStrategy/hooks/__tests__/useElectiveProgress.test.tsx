import React from "react";
import TestRenderer, {act} from "react-test-renderer";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";
import {fetchElectiveProgress} from "../../api/progress.ts";
import {electiveProgressRepo} from "../../repo/ElectiveProgressRepo.ts";
import {useElectiveProgress} from "../useElectiveProgress.ts";
import type {ElectiveProgress} from "../../schema/progress.ts";

jest.mock("@/core/auth/Jw/hooks/useJwAccount.ts", () => ({useJwAccount: jest.fn()}));
jest.mock("../../api/progress.ts", () => ({fetchElectiveProgress: jest.fn()}));
jest.mock("../../repo/ElectiveProgressRepo.ts", () => ({electiveProgressRepo: {get: jest.fn(), save: jest.fn()}}));

function result(studentId: string, totalCredits: number): ElectiveProgress {
    const empty = {credits: 0, courseCount: 0};
    return {
        studentId,
        grade: 2026,
        ruleId: "grade-2026",
        ruleVersion: "2026-v1",
        ruleName: "2026级修读要求",
        computedAt: "2026-11-05T04:00:00.000Z",
        complete: true,
        stats: {
            totalCredits,
            offlineCredits: totalCredits,
            modules: {lead: empty, entrepreneurship: empty, art: empty, asean: empty, ethnic: empty, ocean: empty},
        },
        requirements: [],
        remainingRequired: [],
        courses: [],
        issues: [],
        isQualified: false,
    };
}

function pending<T>() {
    let resolve!: (value: T) => void;
    const promise = new Promise<T>(done => {
        resolve = done;
    });
    return {promise, resolve};
}

describe("服务端校选课结果状态流转", () => {
    let renderer: TestRenderer.ReactTestRenderer;
    let state: ReturnType<typeof useElectiveProgress>;

    function Probe() {
        state = useElectiveProgress();
        return null;
    }
    function account(username: string) {
        jest.mocked(useJwAccount).mockReturnValue({
            username,
            password: "",
            hydrating: false,
            setUsername: jest.fn(),
            setPassword: jest.fn(),
            saveAccount: jest.fn(),
        });
    }

    beforeAll(() => {
        Object.assign(globalThis, {IS_REACT_ACT_ENVIRONMENT: true});
    });
    beforeEach(() => {
        jest.resetAllMocks();
        account("student-1");
    });
    afterEach(async () => {
        await act(async () => {
            renderer?.unmount();
        });
    });

    it("切换账号后不显示旧账号数据，晚到请求也不能覆盖页面或缓存", async () => {
        const old = pending<ElectiveProgress>();
        const current = pending<ElectiveProgress>();
        jest.mocked(electiveProgressRepo.get).mockImplementation(id => (id === "student-1" ? result(id, 1) : null));
        jest.mocked(fetchElectiveProgress).mockImplementation(id =>
            id === "student-1" ? old.promise : current.promise,
        );
        await act(async () => {
            renderer = TestRenderer.create(<Probe />);
        });
        expect(state.data?.studentId).toBe("student-1");
        account("student-2");
        await act(async () => {
            renderer.update(<Probe />);
        });
        expect(state.data).toBeNull();
        const fresh = result("student-2", 2);
        await act(async () => {
            current.resolve(fresh);
        });
        await act(async () => {
            old.resolve(result("student-1", 99));
        });
        expect(state.data).toEqual(fresh);
        expect(electiveProgressRepo.save).toHaveBeenCalledTimes(1);
        expect(electiveProgressRepo.save).toHaveBeenCalledWith("student-2", fresh);
    });

    it("刷新失败保留服务端缓存，重试成功后更新结果并清除错误", async () => {
        const cached = result("student-1", 1);
        jest.mocked(electiveProgressRepo.get).mockReturnValue(cached);
        jest.mocked(fetchElectiveProgress).mockRejectedValue(new Error("教务服务暂不可用"));
        await act(async () => {
            renderer = TestRenderer.create(<Probe />);
        });
        expect(state.data).toEqual(cached);
        expect(state.isCached).toBe(true);
        expect(state.error).toBe("教务服务暂不可用");
        expect(electiveProgressRepo.save).not.toHaveBeenCalled();
        const fresh = result("student-1", 3);
        jest.mocked(fetchElectiveProgress).mockResolvedValue(fresh);
        await act(async () => {
            await state.refresh();
        });
        expect(state.data).toEqual(fresh);
        expect(state.isCached).toBe(false);
        expect(state.error).toBeNull();
    });
});
