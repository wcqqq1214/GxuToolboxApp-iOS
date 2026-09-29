import {useEffect, useState} from "react";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {attendanceApi} from "@/features/attendance/api";
import {RecordPage} from "@gxutool/adapters/attendance";
import {useAttendanceAuth} from "@/core/auth/attendance/hooks/useAttendanceAuth.ts";

export function useRecord(selectedTerm: {year: number; term: number} | null) {
    // Hook 内部自己调 useStartDay，默认拿当前学期。
    // 已经支持“切换历史学期”，在这给 useStartDay 传参数。
    const startDayInfo = useStartDay(selectedTerm?.year, selectedTerm?.term);
    const {authState} = useAttendanceAuth();
    const [page, setPage] = useState(1);
    const [loading, setLoading] = useState(false);
    const [records, setRecords] = useState<RecordPage["items"]>([]);

    const {year, term, ready} = startDayInfo;

    // 2. 封装数据拉取逻辑
    async function fetchRecords() {
        // 如果学期数据还没从 SQLite 里 ready，就不要发网络请求
        if (!ready || authState.status !== "authenticated") return;

        setLoading(true);
        try {
            const res = await attendanceApi.getPersonalDataV2(year, term);
            console.log(res);
            if (res) {
                setRecords(res.items);
            }
        } finally {
            setLoading(false);
        }
    }

    // 3. 依赖联动：当 page 或学期改变时，自动重新 fetch
    useEffect(() => {
        fetchRecords();
    }, [page, year, term, ready, authState]);

    // 4. 将 UI 需要的数据全部透出
    return {
        // 数据状态
        records,
        loading,

        // 分页控制
        page,
        setPage,

        // 手动刷新
        refresh: fetchRecords,

        // 把 UI 可能会用到的学期信息透出给组件
        year,
        term,
        startDay: startDayInfo.startDay, // 用于计算“第几周”
    };
}
