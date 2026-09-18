import {useCallback, useEffect, useMemo, useRef, useState} from "react";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";
import {selectedCourseApi} from "@/features/selectedCourse/api";
import {selectedCourseRepo} from "@/features/selectedCourse/repo/SelectedCourseRepo.ts";
import type {SelectedCourseScope} from "@/features/selectedCourse/type";
import type {SelectedCourse} from "gxu-tool-adapters/jw";

function errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : "已选课程同步失败";
}

export interface UseSelectedCoursesOptions {
    /** 调用方的查询条件尚未就绪时，可暂停本地读取和远端同步。 */
    enabled?: boolean;
}

/**
 * 已选课程的本地优先数据入口。
 * scope 变化时先读取当前账号的 SQLite 缓存，再静默刷新远端；页面无需编排缓存和网络请求。
 */
export function useSelectedCourses(scope: SelectedCourseScope, options: UseSelectedCoursesOptions = {}) {
    const {enabled = true} = options;
    const {username, hydrating} = useJwAccount();
    const [courses, setCourses] = useState<SelectedCourse[]>([]);
    const [loading, setLoading] = useState(false);
    const [refreshing, setRefreshing] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const requestVersion = useRef(0);

    const normalizedScope = useMemo<SelectedCourseScope>(
        () =>
            scope.kind === "all"
                ? {kind: "all"}
                : {
                      kind: "term",
                      year: scope.year,
                      term: scope.term,
                  },
        [scope.kind, scope.kind === "term" ? scope.year : null, scope.kind === "term" ? scope.term : null],
    );

    const refreshRemote = useCallback(
        async (version: number) => {
            if (!enabled) return;

            if (!username) {
                if (requestVersion.current === version) {
                    setRefreshing(false);
                    setError("未找到当前教务账号");
                }
                return;
            }

            if (requestVersion.current === version) {
                setRefreshing(true);
                setError(null);
            }

            try {
                const page = await selectedCourseApi.getList(normalizedScope);
                if (normalizedScope.kind === "all") {
                    await selectedCourseRepo.replaceAll(username, page.items);
                } else {
                    await selectedCourseRepo.replaceByTerm(
                        username,
                        normalizedScope.year,
                        normalizedScope.term,
                        page.items,
                    );
                }

                if (requestVersion.current === version) setCourses(page.items);
            } catch (cause) {
                console.error("[已选课程] 远端同步失败", cause);
                if (requestVersion.current === version) setError(errorMessage(cause));
            } finally {
                if (requestVersion.current === version) setRefreshing(false);
            }
        },
        [enabled, normalizedScope, username],
    );

    const refresh = useCallback(async () => {
        if (hydrating || !enabled) return;
        const version = ++requestVersion.current;
        setLoading(false);
        await refreshRemote(version);
    }, [enabled, hydrating, refreshRemote]);

    useEffect(() => {
        if (!enabled) {
            requestVersion.current += 1;
            setCourses([]);
            setLoading(false);
            setRefreshing(false);
            setError(null);
            return;
        }
        if (hydrating) return;
        const version = ++requestVersion.current;

        const initialize = async () => {
            if (!username) {
                setCourses([]);
                setLoading(false);
                setRefreshing(false);
                setError("未找到当前教务账号");
                return;
            }

            setLoading(true);
            setError(null);
            try {
                const cached = await selectedCourseRepo.getList(username, normalizedScope);
                if (requestVersion.current === version) setCourses(cached);
            } catch (cause) {
                console.error("[已选课程] 读取本地缓存失败", cause);
                if (requestVersion.current === version) setError(errorMessage(cause));
            } finally {
                if (requestVersion.current === version) setLoading(false);
            }

            if (requestVersion.current === version) await refreshRemote(version);
        };

        initialize().catch(cause => {
            console.error("[已选课程] 初始化失败", cause);
            if (requestVersion.current === version) setError(errorMessage(cause));
        });

        return () => {
            if (requestVersion.current === version) requestVersion.current += 1;
        };
    }, [enabled, hydrating, normalizedScope, refreshRemote, username]);

    return {
        courses,
        loading,
        refreshing,
        error,
        refresh,
    };
}
