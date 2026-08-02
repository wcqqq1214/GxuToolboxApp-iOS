import {http, objectToFormUrlEncoded} from "@/core/http.ts";
import {EvaTeacherListRes, TeacherListRes} from "@/features/evaluation/types/schema/TeacherList.ts";

export const evaluationApi = {
    // 获得评价列表
    async getEvaluationList(): Promise<EvaTeacherListRes> {
        const reqBody = objectToFormUrlEncoded({
            queryModel: {
                showCount: 150,
            },
        });
        const res = await http.post("/xspjgl/xspj_cxXspjIndex.html?doType=query&gnmkdm=N401605", reqBody);

        if (typeof res.data !== "object") {
            throw new Error("响应格式异常");
        }

        const valiRes = TeacherListRes.safeParse(res.data);
        if (!valiRes.success) {
            console.error("评教列表校验失败:", valiRes.error.issues);
            console.log("原始响应:", JSON.stringify(res.data));
            throw new Error("数据解析失败");
        }


        return valiRes.data;
    },
    // 获得具体的HTML页面
    async getEvaluationDetail(
        shaWord: string,
        classId: string,
        courseId: string,
        xsdm: string,
        pjmbmcb_id: string,
    ): Promise<String> {
        const reqBody = objectToFormUrlEncoded({
            jgh_id: shaWord,
            jxb_id: classId,
            kch_id: courseId,
            xsdm,
            pjmbmcb_id,
        });
        const res = await http.post("/xspjgl/xspj_cxXspjDisplay.html?gnmkdm=N401605", reqBody);
        if (typeof res.data === "string") {
            return res.data;
        } else {
            throw new Error("HTML获取失败");
        }
    },
    // 只传 default 参数则会消掉所有已有的评价
    async handleEvaResult(Params1: any, Params2?: any): Promise<String> {
        const Params3 = {
            jszdpjbl: "0",
            xykzpjbl: "0",
            "modelList[0].pjzt": "0",
            tjzt: "0",
        };
        const reqBody = objectToFormUrlEncoded({...Params1, ...Params2});
        const res = await http.post("/xspjgl/xspj_bcXspj.html?gnmkdm=N401605", reqBody);
        if (typeof res.data === "string") {
            return res.data;
        } else {
            throw new Error("保存失败");
        }
    },
    async submitEvaResult(Params1: any, Params2?: any): Promise<String> {
        // 这两个参数在提交时必填
        const Params3 = {
            jszdpjbl: "0",
            xykzpjbl: "0",
        };
        const reqBody = objectToFormUrlEncoded({...Params1, ...Params2, ...Params3});
        const res = await http.post("/xspjgl/xspj_tjXspj.html?gnmkdm=N401605", reqBody);
        return res.data;
    },
};
