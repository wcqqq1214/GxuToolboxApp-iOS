import {attendanceMachine} from "@/core/auth/attendance/attendanceMachine.ts";
import {AuthState} from "@/core/auth/createAuthCore.ts";
import {Account} from "@/core/auth/auth.type.ts";
import {SchoolTermValue} from "@/type/global.ts";
import {attendanceApi} from "@/features/attendance/api";
import {attendanceSystemApi} from "@/js/auth/attendanceSystem.ts";
import {AttendanceSystemType as AST} from "@/type/api/auth/attendanceSystem.ts";
import moment from "moment";
import {mmkv} from "@/store/mmkv";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import {create} from "zustand/react";

interface AttendanceStoreState {
    status: AuthState<Account>;
    attendanceList: AST.AttendanceData[];
    normalizedList: ScheduleTableItem[];
}

const useAttendanceStore = create<AttendanceStoreState>()(() => {
    // 同步加载MMKV缓存，避免首次渲染空白
    const cached = mmkv.getObject<AST.AttendanceData[]>("originalAttendanceList");
    const startDayStr = mmkv.getString("attendanceStartDay");
    const list = cached ?? [];
    const normalized = cached && startDayStr ? normalizeAttendance(cached, moment(startDayStr)) : [];
    return {
        status: attendanceMachine.getState(),
        attendanceList: list,
        normalizedList: normalized,
    };
});

function normalizeAttendance(
    raw: AST.AttendanceData[],
    startDay: moment.Moment,
): ScheduleTableItem[] {
    return raw.map(item => ({
        id: `${item.day}-${item.periodSplit}`,
        week: moment(item.day).diff(startDay, "week") + 1,
        day: moment(item.day).day() as ScheduleTableItem['day'],
        begin: Number(item.periodSplit.split(",")[0]) as ScheduleTableItem['begin'],
        end: Number(item.periodSplit.split(",")[1]) as ScheduleTableItem['end'],
        title: item.courseName,
        kind: "attendance",
        status: item.atdStateId,
    }));
}

export const useAttendance = () => {
    function loadCache(): AST.AttendanceData[] | undefined {
        return mmkv.getObject<AST.AttendanceData[]>("originalAttendanceList");
    }

    function saveCache(data: AST.AttendanceData[], startDay: moment.Moment) {
        mmkv.set("originalAttendanceList", data);
        mmkv.set("attendanceStartDay", startDay.toISOString());
    }

    async function init(year: number, term: SchoolTermValue, startDay: moment.Moment) {
        const setData = (raw: AST.AttendanceData[], shouldCache: boolean): void => {
            if (shouldCache) {
                saveCache(raw, startDay);
            }
            const current = useAttendanceStore.getState().attendanceList;
            if (JSON.stringify(current) === JSON.stringify(raw)) return;
            useAttendanceStore.setState({
                attendanceList: raw,
                normalizedList: normalizeAttendance(raw, startDay),
            });
        };

        // 先从MMKV读取缓存快速渲染
        try {
            const cachedRaw = loadCache();
            if (cachedRaw) {
                setData(cachedRaw, false);
            }
        } catch {}

        // 网络请求获取最新考勤数据，成功后覆盖MMKV缓存
        try {
            const authState = await attendanceMachine.refreshToken();
            useAttendanceStore.setState({status: authState});
            if (authState.status !== "authenticated") return;

            const cal = await attendanceSystemApi.calenderData.getBySchoolTerm(year, term);
            if (!cal) return;

            const res = await attendanceApi.getPersonalData(cal.calendarId, 1000);
            const fetchedRaw = res.data.records;

            if (fetchedRaw) {
                setData(fetchedRaw, true);
            }
        } catch {}
    }

    async function update(raw: AST.AttendanceData[], startDay: moment.Moment) {
        saveCache(raw, startDay);
        const current = useAttendanceStore.getState().attendanceList;
        if (JSON.stringify(current) === JSON.stringify(raw)) return;
        useAttendanceStore.setState({
            attendanceList: raw,
            normalizedList: normalizeAttendance(raw, startDay),
        });
    }

    return {
        store: useAttendanceStore,
        init,
        loadCache,
        saveCache,
        update,
    };
};
