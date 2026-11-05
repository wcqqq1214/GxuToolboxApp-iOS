import {useCallback, useEffect, useRef, useState} from "react";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";
import {fetchElectiveProgress} from "../api/progress.ts";
import {electiveProgressRepo} from "../repo/ElectiveProgressRepo.ts";
import type {ElectiveProgress} from "../schema/progress.ts";

interface ProgressState {
    studentId: string;
    data: ElectiveProgress | null;
    isCached: boolean;
    loading: boolean;
    refreshing: boolean;
    error: string | null;
}

const emptyState = (studentId: string): ProgressState => ({
    studentId,
    data: null,
    isCached: false,
    loading: false,
    refreshing: false,
    error: null,
});

/**
 * 作用：先展示当前账号的服务端快照，再刷新后端计算结果
 * 出参：页面所需的结果、加载及错误状态，以及手动刷新入口
 * 修改注意：切换账号或启动新请求后，旧请求不得更新页面或缓存
 */
export function useElectiveProgress() {
    const {username, hydrating} = useJwAccount();
    const studentId = username.trim();
    const [state, setState] = useState<ProgressState>(() => emptyState(""));
    const generation = useRef(0);
    const controller = useRef<AbortController | null>(null);

    const request = useCallback(async (account: string, version: number) => {
        const abort = new AbortController();
        controller.current?.abort();
        controller.current = abort;
        setState(previous => ({...previous, refreshing: true, error: null}));
        try {
            const result = await fetchElectiveProgress(account, abort.signal);
            if (generation.current !== version || abort.signal.aborted) return;
            try {
                electiveProgressRepo.save(account, result);
            } catch (cause) {
                console.warn("[校选课查漏] 服务端结果缓存保存失败", cause);
            }
            setState({
                studentId: account,
                data: result,
                isCached: false,
                loading: false,
                refreshing: false,
                error: null,
            });
        } catch (cause) {
            if (generation.current !== version || abort.signal.aborted) return;
            setState(previous => ({
                ...previous,
                loading: false,
                refreshing: false,
                isCached: previous.data !== null,
                error: cause instanceof Error ? cause.message : "校选课进度获取失败",
            }));
        }
    }, []);

    const refresh = useCallback(async () => {
        if (hydrating || !studentId) return;
        await request(studentId, ++generation.current);
    }, [hydrating, studentId, request]);

    useEffect(() => {
        if (hydrating) return;
        const version = ++generation.current;
        controller.current?.abort();
        const initial = emptyState(studentId);
        if (!studentId) {
            initial.error = "未找到当前教务账号，请先登录";
            setState(initial);
        } else {
            try {
                initial.data = electiveProgressRepo.get(studentId);
            } catch (cause) {
                console.warn("[校选课查漏] 服务端结果缓存读取失败", cause);
            }
            initial.isCached = initial.data !== null;
            initial.loading = initial.data === null;
            setState(initial);
            request(studentId, version);
        }
        return () => {
            generation.current++;
            controller.current?.abort();
        };
    }, [hydrating, studentId, request]);

    const current = state.studentId === studentId ? state : emptyState(studentId);
    return {...current, loading: hydrating || state.studentId !== studentId || current.loading, refresh};
}
