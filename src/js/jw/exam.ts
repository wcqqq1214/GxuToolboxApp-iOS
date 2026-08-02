import {SchoolTerms, SchoolTermValue, SchoolYears} from "@/type/global.ts";
import {ExamInfoQueryRes, ExamScoreQueryRes, UsualScoreQueryRes} from "@/type/api/infoQuery/examInfoAPI.ts";
import {http, objectToFormUrlEncoded} from "@/core/http.ts";
import {ToastAndroid} from "react-native";
import {defaultYear} from "@/js/jw/infoQuery.ts";
import {usualScoreParser} from "@/js/jw/usualScoreParser.ts";
import {ensureJwAuthenticated} from "@/core/auth/Jw/JwMachine.ts";

export const examApi = {
    getExamInfo: async (year: number, term: SchoolTermValue, page: number = 1): Promise<ExamInfoQueryRes | null> => {
        const yearIndex = SchoolYears.findIndex(v => +v[0] === year);
        if (!(await ensureJwAuthenticated())) {
            return null;
        }
        const reqBody = objectToFormUrlEncoded({
            xnm: SchoolYears[yearIndex ?? SchoolYears.findIndex(v => +v[0] === defaultYear)][0],
            xqm: term ?? SchoolTerms[0][0],
            queryModel: {
                showCount: 15,
                currentPage: page > 0 ? page : 1,
                sortName: "",
                sortOrder: "asc",
            },
        });
        const res = await http.post("/kwgl/kscx_cxXsksxxIndex.html?doType=query", reqBody);
        if (typeof res.data === "object") {
            return res.data;
        } else {
            ToastAndroid.show("获取考试信息失败", ToastAndroid.SHORT);
            return null;
        }
    },
    getExamScore: async (
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
    // 获得平时分
    getUsualScore: (year: number, term: SchoolTermValue, id: string): Promise<UsualScoreQueryRes> => {
        const yearIndex = SchoolYears.findIndex(v => +v[0] === year);
        return new Promise(async (resolve, reject) => {
            if (!(await ensureJwAuthenticated())) {
                reject();
                return;
            }
            const reqBody = objectToFormUrlEncoded({
                xnm: SchoolYears[yearIndex ?? SchoolYears.findIndex(v => +v[0] === defaultYear)][0],
                xqm: term ?? SchoolTerms[0][0],
                jxb_id: id,
            });
            const res = await http.post("/cjcx/cjcx_cxCjxqGjh.html?gnmkdm=N305005", reqBody);
            if (res) {
                const i = usualScoreParser(res.data);
                resolve(i);
            } else {
                ToastAndroid.show("获取平时成绩信息失败", ToastAndroid.SHORT);
                reject(res);
            }
        });
    },
};
