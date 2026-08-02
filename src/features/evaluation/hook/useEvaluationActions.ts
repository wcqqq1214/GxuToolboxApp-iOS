import {useState} from "react";
import {ToastAndroid} from "react-native";
import {EvaTeacherList} from "@/features/evaluation/types/schema/TeacherList.ts";
import {Evaluation} from "@/features/evaluation/types/evaluation.type.ts";
import {evaluationApi} from "@/features/evaluation/api";
import {parseEvaluationHTML} from "@/features/evaluation/utils/parser.ts";
import {createDefaultReq, fillReq} from "@/features/evaluation/utils/reqBuilder.ts";
import {useBatchProcessor} from "@/features/evaluation/hook/useBatchProcessor.ts";
import AsyncStorage from "@react-native-async-storage/async-storage";

type Template = {selected: Record<string, Record<string, Record<string, number>>>; comment: string};

export const useEvaluationActions = (
    evaList: EvaTeacherList[],
    refresh: () => Promise<void>,
    onNeedTemplate: () => void,
) => {
    const [isModalVisible, setIsModalVisible] = useState(false);
    const {run, progress, progressText, setProgress, setProgressText, cancel} = useBatchProcessor<Evaluation>();

    const handleOneKey = async () => {
        // 1. 过滤
        const unEvaluatedList = evaList.filter(item => item.submitStatus !== "已评完");
        if (unEvaluatedList.length === 0) {
            ToastAndroid.show("所有项目均已评教，无需操作。", ToastAndroid.SHORT);
            return;
        }

        // 2. 读模板
        let temp: Template;
        try {
            const storedTemp = await AsyncStorage.getItem("@EvaluationTemplate");
            if (!storedTemp) throw new Error("未找到评教模板");
            temp = JSON.parse(storedTemp);
        } catch {
            ToastAndroid.show("加载评教模板失败，请先设置模板。", ToastAndroid.LONG);
            onNeedTemplate();
            return;
        }

        // 3. 单条任务
        const task = async (item: EvaTeacherList, index: number, total: number) => {
            setProgressText(`(${index + 1}/${total}) ${item.courseName} - ${item.teacherName}`);
            setIsModalVisible(true);
            const HtmlText = await evaluationApi.getEvaluationDetail(
                item.securityToken,
                item.teachingClassId,
                item.courseId,
                item.courseTypeCode,
                item.rubricId,
            );
            const {idObj} = parseEvaluationHTML(HtmlText);
            const defReq = createDefaultReq(item, idObj);
            const reqToSend = fillReq(defReq, temp.selected, temp.comment, idObj);
            await evaluationApi.handleEvaResult(defReq, reqToSend);
            setProgress((index + 1) / total);
        };

        // 4. 批量执行 + 刷新
        await run(unEvaluatedList, task);
        setIsModalVisible(false);
        await refresh();
    };

    const handleClear = async () => {
        const task = async (item: EvaTeacherList, index: number, total: number) => {
            setProgressText(`(${index + 1}/${total}) 清空: ${item.courseName}`);
            setIsModalVisible(true);
            const HtmlText = await evaluationApi.getEvaluationDetail(
                item.securityToken,
                item.teachingClassId,
                item.courseId,
                item.courseTypeCode,
                item.rubricId,
            );
            const {idObj} = parseEvaluationHTML(HtmlText);
            const defReq = createDefaultReq(item, idObj);
            await evaluationApi.handleEvaResult(defReq);

            setProgress((index + 1) / total);
        };

        await run(evaList, task);
        setIsModalVisible(false);
        await refresh();
    };

    const submit = async () => {
        const evaluationItem = evaList[0];
        const HtmlText = await evaluationApi.getEvaluationDetail(
            evaluationItem.securityToken,
            evaluationItem.teachingClassId,
            evaluationItem.courseId,
            evaluationItem.courseTypeCode,
            evaluationItem.rubricId,
        );
        const {idObj, selected} = parseEvaluationHTML(HtmlText);
        const defReq = createDefaultReq(evaluationItem, idObj);
        const reqToSend = fillReq(defReq, selected, "", idObj);
        await evaluationApi.submitEvaResult(defReq, reqToSend);
    };

    return {handleOneKey, handleClear, submit, isModalVisible, progress, progressText, cancel};
};
