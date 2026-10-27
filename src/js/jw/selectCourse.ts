import {SchoolTerms, SchoolTermValue, SchoolYears} from "@/type/global.ts";
import {jwxt} from "@/js/jw/jwxt.ts";
import {http, objectToFormUrlEncoded} from "@/core/http.ts";
import {defaultYear} from "@/js/jw/infoQuery.ts";
import {ToastAndroid} from "react-native";

export const CourseSelectionApi = {
    getCourseInfo: async (year: number, term: number): Promise<any> => {
        const yearIndex = SchoolYears.findIndex(v => +v[0] === year);
        const reqBody = objectToFormUrlEncoded({
            xkxnm: SchoolYears[yearIndex ?? SchoolYears.findIndex(v => +v[0] === defaultYear)][0],
            xkxqm: term ?? SchoolTerms[0][0],
            kklxdm: "10",
            kspage: "1",
            jspage: "10",
        });
        const res = await http.post("/xsxk/zzxkyzb_cxZzxkYzbPartDisplay.html?gnmkdm=N253512", reqBody);
        if (typeof res.data === "object") {
            return res.data;
        } else {
            ToastAndroid.show("获取可选课信息失败", ToastAndroid.SHORT);
            return null;
        }
    },
};
