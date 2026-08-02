import {mmkv} from "@/store/mmkv";
import {courseApi} from "@/js/jw/course.ts";
import {CourseClass} from "@/class/jw/course.ts";
import {PhyExpParsed, PhyExpSchema} from "@/type/infoQuery/course/course.ts";
import {PhyExpQueryRes} from "@/type/api/infoQuery/classScheduleAPI.ts";
import {create} from "zustand/react";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import moment from "moment/moment";

interface PhyExpStoreState {
    phyExpList: PhyExpParsed[];
}

const usePhyExpStore = create<PhyExpStoreState>()(() => {
    // 同步加载MMKV缓存，避免首次渲染空白
    const cached = mmkv.getObject<PhyExpQueryRes>("originalPhyExpList");
    if (cached) {
        const list = cached.data
            .map(i => PhyExpSchema.safeParse(i))
            .filter(r => r.success)
            .map(r => r.data);
        return {phyExpList: list};
    }
    return {phyExpList: []};
});

export const usePhyExp = () => {
    function loadCache(): PhyExpQueryRes | undefined {
        return mmkv.getObject<PhyExpQueryRes>("originalPhyExpList");
    }

    function saveCache(data: PhyExpQueryRes) {
        mmkv.set("originalPhyExpList", data);
    }

    async function init() {
        const setData = (res: PhyExpQueryRes, shouldCache: boolean): void => {
            const list = res.data
                .map(i => PhyExpSchema.safeParse(i))
                .filter(r => {
                    if (!r.success) console.warn("物理实验数据解析失败", r.error);
                    return r.success;
                })
                .map(r => r.data);

            if (shouldCache) {
                saveCache(res);
            }

            const current = usePhyExpStore.getState().phyExpList;
            if (JSON.stringify(current) === JSON.stringify(list)) return;
            usePhyExpStore.setState({phyExpList: list});
        };

        // 先从MMKV读取缓存快速渲染
        try {
            const cachedRaw = loadCache();
            if (cachedRaw) {
                setData(cachedRaw, false);
            }
        } catch {}

        // 网络请求获取最新物理实验数据，成功后覆盖MMKV缓存
        try {
            const fetchedRaw = await courseApi.getPhyExpList();
            if (fetchedRaw) {
                setData(fetchedRaw, true);
            }
        } catch (e) {
            console.warn("网络请求失败", e);
        }
    }

    function patchItem(item: ScheduleTableItem, day: moment.Moment): ScheduleTableItem {
        if (item.title !== "大学物理实验") return item;
        const list = usePhyExpStore.getState().phyExpList;
        if (list.length === 0) return item;
        const dateStr = day.format("YYYYMMDD");
        const exp = list.find(e => e.classDate === dateStr);
        if (!exp) return item;
        return {
            ...item,
            title: exp.experimentName || exp.courseName,
            location: exp.location || exp.labName,
            teacher: exp.teacherName || exp.teacherFull,
        };
    }

    function patchCourse(course: CourseClass, day: moment.Moment): CourseClass {
        if (course.transformed.courseName !== "大学物理实验") return course;
        const list = usePhyExpStore.getState().phyExpList;
        if (list.length === 0) return course;
        const dateStr = day.format("YYYYMMDD");
        const exp = list.find(e => e.classDate === dateStr);
        if (!exp) return course;
        return new CourseClass({
            ...course._ori,
            kcmc: exp.experimentName || exp.courseName,
            cdmc: exp.location || exp.labName,
            xm: exp.teacherName || exp.teacherFull,
        });
    }

    return {
        store: usePhyExpStore,
        init,
        loadCache,
        saveCache,
        patchItem,
        patchCourse,
    };
};
