import {useCallback, useState} from "react";
import {ScoreRepo} from "@/features/examScore/type";
import {usual} from "@/features/examScore/api";
import {scoreRepo} from "@/features/examScore/repo/ScoreRepo.ts";

/**
 * 负责查内存 -> 查数据库 -> 查远端并落库的完整生命周期
 * */
export interface UsualScoreItem {
    name: string; // 项目名称（比如"平时成绩"、"期中成绩"）
    ratio: string; // 占比（比如 "30"）
    score: string; // 分数
}
export interface DetailState {
    status: "idle" | "loading" | "success" | "error";
    data?: UsualScoreItem[];
    error?: string;
}

export const useUsualScore = () => {
    const [details, setDetails] = useState<Record<string, DetailState>>({});

    const loadUsualScore = useCallback(async (item: ScoreRepo) => {
        let shouldfetch = false;
        //先从内存加载
        setDetails(prev => {
            if (prev[item.id]) return prev;
            shouldfetch = true;
            return {...prev, [item.id]: {status: "loading"}};
        });

        //再看SQLite
        if (item.usual_score && item.usual_score.trim().length > 5) {
            try {
                const data = JSON.parse(item.usual_score) as UsualScoreItem[];
                if (Array.isArray(data)) {
                    setDetails(prev => ({
                        ...prev,
                        [item.id]: {status: "success", data},
                    }));
                    return;
                }
            } catch (error) {
                console.warn("本地未存平时分，去远端拉取", error);
            }
        }

        try {
            const res = await usual.remote(item.year, item.term, item.id);
            setDetails(prev => ({...prev, [item.id]: {status: "success", data: res.data}}));
            scoreRepo.updateUsualScore(item.id, JSON.stringify(res || [])).catch(console.error);
        } catch (e) {
            console.error("获取平时成绩失败", e);
            setDetails(prev => ({
                ...prev,
                [item.id]: {status: "error", error: "获取平时成绩失败"},
            }));
        }
    }, []);
    return {details, loadUsualScore};
};
