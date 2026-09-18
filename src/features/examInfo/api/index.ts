import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {backendHttp} from "@/features/backend/api";
import type {Exam} from "gxu-tool-adapters/jw";
import {parseExamTime} from "@/features/examInfo/utils/timeParser.ts";

/**
 * 后端 /jw/exam 只接收逻辑学期码 1/2；UI 各处仍可能传旧教务码 3(秋)/12(春)。
 * 与 classScheduleApi 同一套边界约定，在这里统一转换，避免调用方各自记得换码。
 */
function toLogicalTerm(term: string | number): 1 | 2 {
    if (term === 1 || term === 3 || term === "1" || term === "3") return 1;
    if (term === 2 || term === 12 || term === "2" || term === "12") return 2;
    throw new Error(`不支持的学期参数: ${term}`);
}

/**
 * 作用：远端查询考试信息（后端代理 /jw/exam）。
 * 入参：
 * - year：学年字符串。
 * - term：学期码，兼容旧教务码 3/12 与逻辑码 1/2。
 * 出参：ExamWithMeta[]（含动态计算的 date/status）+ 每条带 updatedAt（秒级，供落库）。null 表示后端无数据。
 */
export async function getExamInfo(year: string, term: string): Promise<(ExamWithMeta & {updatedAt: number})[] | null> {
    const params = {year, term: toLogicalTerm(term)};
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
