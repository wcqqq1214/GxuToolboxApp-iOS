import {useCallback, useState} from "react";
import {getExamInfo} from "@/features/examInfo/api";
import {examInfoRepo} from "@/features/examInfo/repo/ExamInfoRepo.ts";
import {ExamInfoRepo} from "@/features/examInfo/type";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {parseExamTime} from "@/features/examInfo/utils/timeParser.ts";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";

/**
 * 作用：考试信息的本地优先 + 后台静默更新 hook。
 * - loadLocal：读 SQLite，瞬间展示旧数据。
 * - fetchRemote：拉网络，replaceByTerm 落库，刷新界面。
 * date/status 不落库，读取时动态计算。
 */
export function useExamInfo() {
    const {username} = useJwAccount();
    const [exams, setExams] = useState<ExamWithMeta[]>([]);
    const [isLoading, setIsLoading] = useState(false);

    /** 将 DB 原始记录转为带 date/status 的运行时对象。 */
    function toExamWithMeta(items: ExamInfoRepo[]): ExamWithMeta[] {
        return items.map(item => {
            const {date, status} = parseExamTime(item.time);
            return {
                id: item.id,
                course: item.course,
                classroom: item.classroom,
                time: item.time,
                type: item.type,
                seat: item.seat,
                date,
                status,
            };
        });
    }

    // 从本地数据库加载缓存。term 为逻辑码 1/2。
    const loadLocal = useCallback(
        async (year: number | "", term: string | number | "") => {
            if (!username) return;
            setIsLoading(true);
            try {
                const data = await examInfoRepo.getList(username, year, term);
                setExams(toExamWithMeta(data));
            } finally {
                setIsLoading(false);
            }
        },
        [username],
    );

    // 从远端请求并更新本地。term 为逻辑码 1/2。
    const fetchRemote = useCallback(
        async (year: number, term: string | number) => {
            if (!username) return null;
            setIsLoading(true);
            try {
                const res = await getExamInfo(String(year), String(term));
                // 远端明确返回空时也要用空集合替换缓存，避免已取消的考试继续残留。
                const items: ExamInfoRepo[] = (res ?? []).map(r => ({
                    id: r.id,
                    studentId: username,
                    year,
                    term: Number(term),
                    course: r.course,
                    classroom: r.classroom,
                    time: r.time,
                    type: r.type,
                    seat: r.seat,
                    updatedAt: r.updatedAt,
                }));
                await examInfoRepo.replaceByTerm(username, year, Number(term), items);
                setExams(toExamWithMeta(items));
                return res;
            } finally {
                setIsLoading(false);
            }
        },
        [username],
    );

    return {
        exams,
        isLoading,
        loadLocal,
        fetchRemote,
    };
}
