import {backendHttp} from "@/features/backend/api";
import {ensureJwAuthenticated} from "@/core/auth/Jw/JwMachine.ts";
import {ApiResponse} from "@/core/type/global.ts";
import {ScoreData} from "@/features/examScore/type";
import {UsualScoreItem} from "@/features/examScore/hooks/useUsualScore.ts";

const exam = {
    /** 远端成绩查询（后端代理 /jw/score，term 为逻辑学期码 1/2）。 */
    remote: async (
        year: number | "" = "",
        term: string | number | "" = "",
        page: number = 1,
        limit: number = 15,
    ): Promise<ApiResponse<ScoreData> | null> => {
        if (!(await ensureJwAuthenticated())) {
            return null;
        }

        const params = {
            pageSize: limit,
            pageNo: page > 0 ? page : 1,
            orderBy: "desc",
            order: "cjbdsj",
            ...(year !== "" && {year}),
            ...(term !== "" && {term}),
        };

        const res = await backendHttp.get("/jw/score", {params});

        if (typeof res?.data === "object") {
            return res.data;
        }
        return null;
    },
};

export const usual = {
    remote: async (
        year: number | "" = "",
        term: string | number | "" = "",
        id: string,
    ): Promise<ApiResponse<UsualScoreItem[]> | null> => {
        if (!(await ensureJwAuthenticated())) {
            return null;
        }

        const params = {
            ...(year !== "" && {year}),
            ...(term !== "" && {term}),
            id,
        };

        const res = await backendHttp.get("/jw/score/usual", {params});

        if (typeof res?.data === "object") {
            return res.data;
        }
        return null;
    },
};

export const getExamScore = (
    year: number | "" = "",
    term: string | number | "" = "",
    page: number = 1,
    limit: number = 1000,
) => {
    return exam.remote(year, term, page, limit);
};
