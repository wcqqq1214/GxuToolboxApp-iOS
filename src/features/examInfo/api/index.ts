import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {backendHttp} from "@/features/backend/api";
import type {Exam} from "gxu-tool-adapters/jw";
import {parseExamTime} from "@/features/examInfo/utils/timeParser.ts";

export async function getExamInfo(year: string, term: string): Promise<ExamWithMeta[] | null> {
    const localTerm = term === "3" ? "1" : "2";
    const params = {year, term: localTerm};
    const res = await backendHttp.get("/jw/exam", {params});
    if (res.data.data !== null) {
        return res.data.data.map((r: Exam) => {
            const {date, status} = parseExamTime(r.time);
            return {
                ...r,
                seat: (r as any).seat ?? "", // 教务系统不放座位号了
                date,
                status,
            };
        });
    } else {
        return null;
    }
}
