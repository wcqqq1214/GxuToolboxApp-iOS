import {useCallback, useEffect, useMemo, useRef, useState} from "react";
import dayjs from "dayjs";
import {getExamScore} from "@/features/examScore/api";
import {scoreRepo} from "@/features/examScore/repo/ScoreRepo.ts";
import type {ScoreRepo} from "@/features/examScore/type";
import {useSelectedCourses} from "@/features/selectedCourse/hooks/useSelectedCourses.ts";
import type {AcademicTerm, SelectedCourseScope} from "@/features/selectedCourse/type";
import {isAcademicTerm} from "@/features/selectedCourse/type";

type QueryValue = string | number | null | undefined;

interface ScoreQuery {
    year: number;
    term: AcademicTerm;
}

interface RemoteScoreResult {
    items: ScoreRepo[];
    totalCount: number;
    totalPage: number;
    syncedAt: number;
}

function normalizeQuery(year: QueryValue, term: QueryValue): ScoreQuery | null {
    const normalizedYear = Number(year);
    const normalizedTerm = Number(term);

    if (
        year == null ||
        year === "" ||
        normalizedYear <= 0 ||
        !Number.isInteger(normalizedYear) ||
        !isAcademicTerm(normalizedTerm)
    ) {
        return null;
    }
    return {year: normalizedYear, term: normalizedTerm};
}

function formatSyncTime(timestamp: number): string {
    // 兼容旧缓存中误用毫秒的 updated_at；新数据统一使用秒级 Unix 时间戳。
    const time = timestamp > 10_000_000_000 ? dayjs(timestamp) : dayjs.unix(timestamp);
    return time.format("MM月DD日 HH:mm:ss");
}

async function fetchRemoteScores(query: ScoreQuery): Promise<RemoteScoreResult | null> {
    const response = await getExamScore(query.year, query.term);
    if (!response?.data) return null;

    const syncedAt = Math.floor(Date.now() / 1000);
    const items = (response.data.items ?? []).map(item => ({...item, updated_at: syncedAt}));

    return {
        items,
        totalCount: response.data.totalCount ?? 0,
        totalPage: response.data.totalPage ?? 1,
        syncedAt,
    };
}

function errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : "考试成绩同步失败";
}

/**
 * 考试成绩页的数据入口：成绩与已选课程都按同一学期本地优先加载，并在后台静默刷新。
 * 页面只提供查询学期，未出分课程通过 SelectedCourse.classId 与 Score.id 的差集得出。
 */
export function useScore(year: QueryValue = "", term: QueryValue = "") {
    const query = useMemo(() => normalizeQuery(year, term), [term, year]);
    const selectedCourseScope = useMemo<SelectedCourseScope>(
        () => ({kind: "term", year: query?.year ?? 0, term: query?.term ?? 1}),
        [query?.term, query?.year],
    );
    const {
        courses,
        loading: coursesLoading,
        refreshing: coursesRefreshing,
        error: coursesError,
        refresh: refreshCourses,
    } = useSelectedCourses(selectedCourseScope, {enabled: query !== null});

    const [scores, setScores] = useState<ScoreRepo[]>([]);
    const [pageInfo, setPageInfo] = useState({totalCount: 0, totalPage: 1});
    const [loading, setLoading] = useState(false);
    const [refreshing, setRefreshing] = useState(false);
    const [scoreError, setScoreError] = useState<string | null>(null);
    const [lastSyncTime, setLastSyncTime] = useState("");
    const requestVersion = useRef(0);

    const refreshScores = useCallback(async (version: number, activeQuery: ScoreQuery) => {
        if (requestVersion.current === version) {
            setRefreshing(true);
            setScoreError(null);
        }

        try {
            const result = await fetchRemoteScores(activeQuery);
            if (!result || requestVersion.current !== version) return;

            setScores(result.items);
            setPageInfo({totalCount: result.totalCount, totalPage: result.totalPage});
            setLastSyncTime(formatSyncTime(result.syncedAt));
            await scoreRepo.upsert(result.items);
        } catch (cause) {
            if (requestVersion.current === version) setScoreError(errorMessage(cause));
        } finally {
            if (requestVersion.current === version) setRefreshing(false);
        }
    }, []);

    const refresh = useCallback(async () => {
        if (!query) return;

        const version = ++requestVersion.current;
        setLoading(false);
        await Promise.all([refreshScores(version, query), refreshCourses()]);
    }, [query, refreshCourses, refreshScores]);

    useEffect(() => {
        const version = ++requestVersion.current;

        if (!query) {
            setScores([]);
            setPageInfo({totalCount: 0, totalPage: 1});
            setLoading(false);
            setRefreshing(false);
            setScoreError(null);
            setLastSyncTime("");
            return;
        }

        const init = async () => {
            setLoading(true);
            setScoreError(null);
            try {
                const cached = await scoreRepo.getList(query.year, query.term);
                if (requestVersion.current === version) {
                    setScores(cached);
                    setPageInfo({totalCount: cached.length, totalPage: 1});
                    setLastSyncTime(cached[0]?.updated_at ? formatSyncTime(cached[0].updated_at) : "");
                }
            } catch (cause) {
                if (requestVersion.current === version) setScoreError(errorMessage(cause));
            } finally {
                if (requestVersion.current === version) setLoading(false);
            }

            if (requestVersion.current === version) await refreshScores(version, query);
        };

        init().catch(cause => {
            if (requestVersion.current === version) setScoreError(errorMessage(cause));
        });

        return () => {
            if (requestVersion.current === version) requestVersion.current += 1;
        };
    }, [query, refreshScores]);

    const notScore = useMemo(() => {
        const scoredClassIds = new Set(scores.map(score => score.id));
        return courses.filter(course => !scoredClassIds.has(course.classId));
    }, [courses, scores]);

    return {
        scores,
        notScore,
        pageInfo,
        loading,
        refreshing,
        isLoading: loading || refreshing || coursesLoading || coursesRefreshing,
        error: scoreError ?? coursesError,
        lastSyncTime,
        refresh,
    };
}
