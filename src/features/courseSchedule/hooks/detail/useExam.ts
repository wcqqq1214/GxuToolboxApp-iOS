import {mmkv} from "@/store/mmkv";
import {SchoolTermValue} from "@/type/global.ts";
import {normalizeExam} from "@/features/courseSchedule/utils/normalizeExam.ts";
import {getExamInfo} from "@/features/examInfo/api";
import {ensureJwAuthenticated} from "@/core/auth/Jw/JwMachine.ts";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import {ExamWithMeta, StoredExam} from "@/features/examInfo/type/exam.types.ts";
import {parseExamTime} from "@/features/examInfo/utils/timeParser.ts";
import moment from "moment";
import {create} from "zustand/react";

interface ExamStoreState {
    examList: ScheduleTableItem<ExamWithMeta>[];
}

/** 缓存配套的元信息：缓存属于哪个学年/学期，以及算 week 用的开学日。 */
interface ExamCacheMeta {
    year: number;
    term: SchoolTermValue;
    startDay: string;
}

const EXAM_CACHE_KEY = "scheduleExamCache";
const EXAM_CACHE_META_KEY = "scheduleExamCacheMeta";

/** 把 MMKV 里的纯数据补回运行时计算出来的 date/status。 */
function toExamWithMeta(items: StoredExam[]): ExamWithMeta[] {
    return items.map(item => {
        const {date, status} = parseExamTime(item.time);
        return {...item, date, status};
    });
}

/** toExamWithMeta 的逆向：只保留可持久化的字段，丢掉 date/status 里的 dayjs 实例。 */
function toStoredExam(items: ExamWithMeta[]): StoredExam[] {
    return items.map(item => ({
        id: item.id,
        course: item.course,
        classroom: item.classroom,
        time: item.time,
        type: item.type,
        seat: item.seat,
    }));
}

/** 同步读取缓存；无数据或元信息不完整时返回 null。 */
function readCache(): {items: StoredExam[]; meta: ExamCacheMeta} | null {
    const items = mmkv.getObject<StoredExam[]>(EXAM_CACHE_KEY);
    const meta = mmkv.getObject<ExamCacheMeta>(EXAM_CACHE_META_KEY);
    if (!items || !meta?.startDay) return null;
    return {items, meta};
}

const useExamStore = create<ExamStoreState>()(() => {
    // 同步加载MMKV缓存，避免首次渲染空白
    const cached = readCache();
    if (cached) {
        return {
            examList: normalizeExam(toExamWithMeta(cached.items), moment(cached.meta.startDay)),
        };
    }
    return {examList: []};
});

export const useExam = () => {
    function loadCache() {
        const cached = readCache();
        if (!cached) return;

        useExamStore.setState({
            examList: normalizeExam(toExamWithMeta(cached.items), moment(cached.meta.startDay)),
        });
    }

    function saveCache(data: StoredExam[], year: number, term: SchoolTermValue, startDay: moment.Moment) {
        mmkv.set(EXAM_CACHE_KEY, data);
        mmkv.set(EXAM_CACHE_META_KEY, {year, term, startDay: startDay.toISOString()} satisfies ExamCacheMeta);
    }

    async function init(year: number, term: SchoolTermValue, startDay: moment.Moment) {
        const setData = (items: ExamWithMeta[], shouldCache: boolean) => {
            const newModel = normalizeExam(items, startDay);

            if (shouldCache) {
                saveCache(toStoredExam(items), year, term, startDay);
            }

            const current = useExamStore.getState().examList;
            if (JSON.stringify(current) === JSON.stringify(newModel)) return;
            useExamStore.setState({examList: newModel});
        };

        // 先从MMKV读取缓存快速渲染；学年/学期对不上就视为无缓存
        try {
            const cached = readCache();
            if (cached && cached.meta.year === year && cached.meta.term === term) {
                setData(toExamWithMeta(cached.items), false);
            }
        } catch {}

        // 网络请求获取最新考试数据，成功后覆盖MMKV缓存
        try {
            // 后端代理依赖教务 Cookie 已同步到后端域，保持改动前的鉴权守卫
            if (!(await ensureJwAuthenticated())) return;

            const fetched = await getExamInfo(String(year), String(term));
            if (fetched) {
                setData(fetched, true);
            }
        } catch (e) {
            // 请求失败保留本地已有数据，不清空
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
