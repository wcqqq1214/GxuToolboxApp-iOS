import {useCallback, useMemo, useState} from "react";
import {EvaTeacherList} from "@/features/evaluation/types/schema/TeacherList.ts";
import {AuthStateMap} from "@/core/auth/auth.type.ts";
import {Alert, ToastAndroid} from "react-native";
import {evaluationApi} from "@/features/evaluation/api";
import {useJwAuth} from "@/core/auth/Jw/hooks/useJwAuth.ts";

/**
 * detail hook 只管"对单个教师做什么"，
 * actions hook 只管"批量编排谁来做"，
 * list hook 只管"有哪些人"。
 * 各自拥有自己的数据，不越界。
 */
export const useEvaluationList = () => {
    const STATUS_ORDER = ["已评完", "未评完", "未评"];

    const {authState} = useJwAuth();
    const [list, setList] = useState<EvaTeacherList[]>([]);
    const [loading, setLoading] = useState(false);

    const init = useCallback(async () => {
        try {
            if (authState.status !== AuthStateMap.Authenticated) {
                Alert.alert("需要登录", "此操作需要登录教务系统");
                return;
            }
            setLoading(true);
            const res = await evaluationApi.getEvaluationList();
            res.items.sort((a, b) => STATUS_ORDER.indexOf(a.submitStatus) - STATUS_ORDER.indexOf(b.submitStatus));
            setList(res.items);
        } catch (e) {
            console.error("获取评教列表失败:", e);
            ToastAndroid.show("获取评教列表失败", ToastAndroid.SHORT);
        } finally {
            setLoading(false);
        }
    }, [authState.status]);

    const statusCounts = useMemo(() => {
        const cnt = {done: 0, undone: 0, undo: 0};
        list.forEach(item => {
            switch (item.submitStatus) {
                case "已评完":
                    cnt.done++;
                    break;

                case "未评完":
                    cnt.undone++;
                    break;
                case "未评":
                    cnt.undo++;
                    break;
                default:
                    break;
            }
        });
        return cnt;
    }, [list]);

    return {list, loading, init, statusCounts};
};
