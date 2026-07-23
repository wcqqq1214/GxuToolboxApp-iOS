import {useCallback, useState} from "react";
import {getExamScore} from "@/features/examScore/api";
import {scoreRepo} from "@/features/examScore/repo/ScoreRepo.ts";
import {ScoreRepo} from "@/features/examScore/type";
import dayjs from "dayjs";

export function useScore() {
    const [scores, setScores] = useState<ScoreRepo[]>([]);
    const [pageInfo, setPageInfo] = useState({totalCount: 0, totalPage: 1});
    const [isLoading, setIsLoading] = useState(false);

    const [lastSyncTime, setLastSyncTime] = useState<string>("");

    // 从本地数据库加载缓存
    const loadLocal = useCallback(async (year: number | "", term: number | "") => {
        setIsLoading(true);
        try {
            const data = await scoreRepo.getList(year, term);
            if (data && data.length > 0) {
                setScores(data);
                setPageInfo({totalCount: data.length, totalPage: 1});

                if (data[0].updated_at) {
                    setLastSyncTime(dayjs(data[0].updated_at).format("MM月DD日 HH:mm:ss"));
                }
            } else {
                setScores([]); // 切换学期时如果没有缓存要清空
                setLastSyncTime("");
            }
        } finally {
            setIsLoading(false);
        }
    }, []);

    // 从远端请求并更新本地
    const fetchRemote = useCallback(async (year: number, term: string | number, page: number = 1) => {
        setIsLoading(true);
        try {
            // 教务系统的恶心映射在组件外处理
            let newTerm: number | "" = "";
            if (term === "3" || term === 3) newTerm = 1;
            if (term === "12" || term === 12) newTerm = 2;

            const res = await getExamScore(year, newTerm, page);

            if (res?.data) {
                const now = Date.now();

                // 所有记录的 updated_at 全部强行变成当前时间戳
                // 刷新界面的时间，也在 upsert 时强行更新数据库里的 updated_at
                const items = (res.data.items || []).map(item => ({...item, updated_at: now}));

                setScores(items);
                setPageInfo({
                    totalCount: res.data.totalCount || 0,
                    totalPage: res.data.totalPage || 1,
                });

                setLastSyncTime(dayjs(now).format("MM月DD日 HH:mm:ss"));
                // 异步落库，不需要 await 等它存完才渲染
                scoreRepo.upsert(items).catch(console.error);
                return res.data;
            }
        } finally {
            setIsLoading(false);
        }
        return null;
    }, []);

    return {
        scores,
        pageInfo,
        isLoading,
        lastSyncTime,
        loadLocal,
        fetchRemote,
    };
}
