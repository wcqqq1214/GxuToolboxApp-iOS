import {mmkv} from "@/store/mmkv";
import {SchoolTermValue} from "@/type/global.ts";
import {IExam} from "@/features/courseSchedule/type/schema/exam.ts";
import {normalizeExam} from "@/features/courseSchedule/utils/normalizeExam.ts";
import {examApi} from "@/js/jw/exam.ts";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import {ExamInfo} from "@/type/infoQuery/exam/examInfo.ts";
import {ExamInfoQueryRes} from "@/type/api/infoQuery/examInfoAPI.ts";
import moment from "moment";
import {create} from "zustand/react";

interface ExamStoreState {
    examRaw: ExamInfo[];
    examList: ScheduleTableItem<ExamInfo>[];
}

const useExamStore = create<ExamStoreState>()(() => {
    // 同步加载MMKV缓存，避免首次渲染空白
    const cached = mmkv.getObject<ExamInfoQueryRes>("originalExamList");
    const startDayStr = mmkv.getString("examStartDay");
    if (cached && startDayStr) {
        const parsed = IExam.safeParse(cached.items);
        if (parsed.success) {
            return {
                examRaw: cached.items,
                examList: normalizeExam(parsed.data, moment(startDayStr), cached.items),
            };
        }
    }
    return {examRaw: cached?.items ?? [], examList: []};
});

export const useExam = () => {
    function loadCache(): ExamInfoQueryRes | undefined {
        return mmkv.getObject<ExamInfoQueryRes>("originalExamList");
    }

    function saveCache(data: ExamInfoQueryRes, startDay: moment.Moment) {
        mmkv.set("originalExamList", data);
        mmkv.set("examStartDay", startDay.toISOString());
    }

    async function init(year: number, term: SchoolTermValue, startDay: moment.Moment) {
        const setData = (raw: ExamInfoQueryRes, shouldCache: boolean) => {
            if (!raw) return;

            const parsed = IExam.safeParse(raw.items);
            if (!parsed.success) {
                console.warn("解析原始数据失败", parsed.error);
                return;
            }
            const newModel = normalizeExam(parsed.data, startDay, raw.items);

            if (shouldCache) {
                saveCache(raw, startDay);
            }

            const current = useExamStore.getState().examList;
            if (JSON.stringify(current) === JSON.stringify(newModel)) return;
            useExamStore.setState({
                examRaw: raw.items,
                examList: newModel,
            });
        };

        // 先从MMKV读取缓存快速渲染
        try {
            const cachedRaw = loadCache();
            if (cachedRaw) {
                setData(cachedRaw, false);
            }
        } catch {}

        // 网络请求获取最新考试数据，成功后覆盖MMKV缓存
        try {
            const fetchedRaw = await examApi.getExamInfo(year, term);
            if (fetchedRaw) {
                setData(fetchedRaw, true);
            }
        } catch (e) {
            console.warn("网络请求失败", e);
        }
    }

    return {
        store: useExamStore,
        init,
        loadCache,
        saveCache,
    };
};
