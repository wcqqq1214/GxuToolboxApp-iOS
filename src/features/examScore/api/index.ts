import {runJw} from "@/core/gateway/jw/run.ts";
import {SchoolTerms, SchoolTermValue, SchoolYears} from "@/type/global.ts";
import {ExamScoreQueryRes} from "@/type/api/infoQuery/examInfoAPI.ts";
import {ensureJwAuthenticated} from "@/core/auth/Jw/JwMachine.ts";
import {http, objectToFormUrlEncoded} from "@/core/http.ts";
import {defaultYear} from "@/js/jw/infoQuery.ts";
import {ToastAndroid} from "react-native";
import {backendHttp} from "@/features/backend/api";
import {ScoreData} from "@/features/examScore/type";
import {ApiResponse} from "@/core/type/global.ts";
import {UsualScoreItem} from "@/features/examScore/hooks/useUsualScore.ts";

const exam = {
    remote: async (
        year: number | "" = "",
        term: number | "" = "",
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
            console.log(res.data);
            return res.data;
        }
        return null;
    },
    local: async (
        year: number | "" = "",
        term: SchoolTermValue | "" = "",
        page: number = 1,
        limit: number = 15,
    ): Promise<ExamScoreQueryRes | null> => {
        if (!(await ensureJwAuthenticated())) {
            return null;
        }
        const reqBody = objectToFormUrlEncoded({
            xnm: year === "" ? "" : (SchoolYears.find(v => +v[0] === year)?.[0] ?? defaultYear),
            xqm: term === "" ? "" : (term ?? SchoolTerms[0][0]),
            queryModel: {
                showCount: limit,
                currentPage: page > 0 ? page : 1,
                sortName: "cjbdsj",
                sortOrder: "desc",
            },
        });
        const res = await http.post("/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005", reqBody);
        if (typeof res.data === "object") {
            return res.data;
        } else {
            ToastAndroid.show("获取考试成绩信息失败", ToastAndroid.SHORT);
            return null;
        }
    },
};

export const usual = {
    remote: async (
        year: number | "" = "",
        term: number | "" = "",
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
            console.log(res.data);
            return res.data;
        }
        return null;
    },
};

export const getExamScore = (year: number | "" = "", term: number | "" = "", page: number = 1, limit: number = 15) => {
    return runJw(
        () => exam.remote(year, term, page, limit),
        () => exam.local(year, term as SchoolTermValue, page, limit), // 注意这里的强转，因为你的 local 签名里 term 还是 SchoolTermValue
    );
};
// export const getUsualScore = () => runJw(usual.remote, usual.local);
