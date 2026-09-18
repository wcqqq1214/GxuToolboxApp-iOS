import {SchoolTerms, SchoolTermValue, SchoolYears} from "@/type/global.ts";
import {ExamInfoQueryRes} from "@/type/api/infoQuery/examInfoAPI.ts";
import {http, objectToFormUrlEncoded} from "@/core/http.ts";
import {ToastAndroid} from "react-native";
import {defaultYear} from "@/js/jw/infoQuery.ts";
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
};
