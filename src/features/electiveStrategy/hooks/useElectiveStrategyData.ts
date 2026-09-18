import {useEffect, useMemo, useState} from "react";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";
import {userProfileRepo} from "@/core/repo/userProfileRepo.ts";
import {getExamScore} from "@/features/examScore/api";
import {scoreRepo} from "@/features/examScore/repo/ScoreRepo.ts";
import type {ScoreRepo} from "@/features/examScore/type";
import {useSelectedCourses} from "@/features/selectedCourse/hooks/useSelectedCourses.ts";

const ALL_SELECTED_COURSES = {kind: "all"} as const;
const DEFAULT_GRADE = 2025;

export interface PassedScore {
    courseName: string;
    score: number;
}

function passedScores(scores: ScoreRepo[]): PassedScore[] {
    return scores
        .filter(item => item.score >= 60)
        .map(item => ({
            courseName: item.course_name,
            score: Number(item.score),
        }));
}

function errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : "校选课查漏数据加载失败";
}

/**
 * 校选课查漏的数据入口。
 * 已选课程和成绩均先使用本地缓存再静默刷新；个人信息缺失时降级使用默认培养方案。
 */
export function useElectiveStrategyData() {
    const {username, hydrating} = useJwAccount();
    const selectedCourseState = useSelectedCourses(ALL_SELECTED_COURSES, {
        enabled: !hydrating && Boolean(username),
    });
    const courses = useMemo(
        () => selectedCourseState.courses.filter(course => course.selectionType === "通识选修课"),
        [selectedCourseState.courses],
    );

    const [scores, setScores] = useState<PassedScore[]>([]);
    const [userGrade, setUserGrade] = useState(DEFAULT_GRADE);
    const [loading, setLoading] = useState(false);
    const [refreshing, setRefreshing] = useState(false);
    const [scoreError, setScoreError] = useState<string | null>(null);

    useEffect(() => {
        let active = true;

        if (hydrating) return () => undefined;
        if (!username) {
            setScores([]);
            setUserGrade(DEFAULT_GRADE);
            setLoading(false);
            setRefreshing(false);
            setScoreError("未找到当前教务账号");
            return () => undefined;
        }

        const initialize = async () => {
            setLoading(true);
            setScoreError(null);

            const [profileResult, cachedScoreResult] = await Promise.allSettled([
                userProfileRepo.get(username),
                scoreRepo.getList("", ""),
            ]);
            if (!active) return;

            if (profileResult.status === "fulfilled") {
                const grade = Number(profileResult.value?.grade);
                setUserGrade(Number.isInteger(grade) && grade > 0 ? grade : DEFAULT_GRADE);
            } else {
                // 个人信息只决定培养方案；读取失败时允许页面继续使用默认年级。
                console.error("[校选课查漏] 读取个人信息失败，已使用默认年级", profileResult.reason);
                setUserGrade(DEFAULT_GRADE);
            }

            if (cachedScoreResult.status === "fulfilled") {
                setScores(passedScores(cachedScoreResult.value));
            } else {
                // 本地缓存失败不阻断远端刷新。
                console.error("[校选课查漏] 读取本地成绩失败", cachedScoreResult.reason);
            }
            setLoading(false);

            setRefreshing(true);
            try {
                const response = await getExamScore("", "", 1, 1000);
                const items = response?.data?.items;
                if (!Array.isArray(items)) throw new Error("考试成绩接口返回的数据格式异常");

                const syncedAt = Math.floor(Date.now() / 1000);
                const normalized = items.map(item => ({...item, updated_at: syncedAt}));
                if (active) {
                    setScores(passedScores(normalized));
                    setScoreError(null);
                }

                await scoreRepo.upsert(normalized);
            } catch (cause) {
                console.error("[校选课查漏] 刷新成绩失败", cause);
                if (active) setScoreError(errorMessage(cause));
            } finally {
                if (active) setRefreshing(false);
            }
        };

        initialize().catch(cause => {
            console.error("[校选课查漏] 初始化失败", cause);
            if (active) {
                setLoading(false);
                setRefreshing(false);
                setScoreError(errorMessage(cause));
            }
        });

        return () => {
            active = false;
        };
    }, [hydrating, username]);

    const fatalCourseError = selectedCourseState.error && courses.length === 0 ? selectedCourseState.error : null;
    const fatalScoreError = scoreError && scores.length === 0 ? scoreError : null;

    return {
        courses,
        scores,
        userGrade,
        loading:
            hydrating ||
            loading ||
            selectedCourseState.loading ||
            (courses.length === 0 && selectedCourseState.refreshing) ||
            (scores.length === 0 && refreshing),
        refreshing: refreshing || selectedCourseState.refreshing,
        error: fatalCourseError ?? fatalScoreError,
    };
}
