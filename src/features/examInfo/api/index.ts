import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {backendHttp} from "@/features/backend/api";
import type {Exam} from "gxu-tool-adapters/jw";
import {parseExamTime} from "@/features/examInfo/utils/timeParser.ts";

/**
 * 作用：远端查询考试信息（后端代理 /jw/exam）。
 * 入参：
 * - year：学年字符串。
 * - term：学期码 "1"/"2"。
 * 出参：ExamWithMeta[]（含动态计算的 date/status）+ 每条带 updatedAt（秒级，供落库）。null 表示后端无数据。
 */
export async function getExamInfo(year: string, term: string): Promise<(ExamWithMeta & {updatedAt: number})[] | null> {
    const params = {year, term};
    const res = await backendHttp.get("/jw/exam", {params});
    if (res.data.data !== null) {
        const now = Math.floor(Date.now() / 1000);
        return res.data.data.map((r: Exam) => {
            const {date, status} = parseExamTime(r.time);
            return {
                ...r,
                seat: (r as any).seat ?? "", // 教务系统不放座位号了
                date,
                status,
                updatedAt: now,
            };
        });
    } else {
        return null;
    }
}
