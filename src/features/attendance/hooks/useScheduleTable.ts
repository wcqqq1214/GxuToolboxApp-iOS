import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {useAttendanceAuth} from "@/core/auth/attendance/hooks/useAttendanceAuth.ts";
import {useEffect, useMemo, useState} from "react";
import {attendanceApi} from "@/features/attendance/api";
import moment from "moment";
import {useRecord} from "@/features/attendance/hooks/useRecord.ts";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";

export function useScheduleTable(selectedTerm: {year: number; term: number} | null) {
    const startDayInfo = useStartDay(selectedTerm?.year, selectedTerm?.term);
    const {authState} = useAttendanceAuth();
    const [loading, setLoading] = useState(false);
    const [schedule, setSchedule] = useState<ScheduleTableItem[]>([]);
    const {records} = useRecord(selectedTerm);

    const {year, term, startDay, ready} = startDayInfo;
    const [week, setWeek] = useState(moment().diff(startDay, "week") + 1);
    const [totalWeeks, setTotalWeeks] = useState<number>(20);

    const statusMap = useMemo(
        () => new Map(records.map(record => [`${record.date}-${record.periodRange}`, record.statusCode])),
        [records],
    );

    const displaySchedule = useMemo(
        () =>
            schedule.map(item => ({
                ...item,
                status: statusMap.get(item.id),
            })),
        [schedule, statusMap],
    );

    // 2. 封装数据拉取逻辑
    async function fetchSchedule() {
        // 如果学期数据还没从 SQLite 里 ready，就不要发网络请求
        if (!ready || authState.status !== "authenticated") return;

        setLoading(true);
        try {
            const res = await attendanceApi.getTableDataV2(year, term, week);
            const items = res?.rows.flatMap((row, rowIndex) =>
                row.courses.flatMap(course => {
                    if ((course.subjectId === null || course.subjectId === 0) && !course.subjectName) return [];

                    const dateText = course.date ?? row.date;
                    if (!dateText || !course.subjectName) return [];

                    const begin = course.periods?.[0] ?? rowIndex + 1;
                    const end = course.periods?.at(-1) ?? begin + course.connectedCount;

                    return begin === end
                        ? []
                        : [
                              {
                                  id: `${dateText}-${begin},${end}`,
                                  week,
                                  day: moment(dateText).isoWeekday() as ScheduleTableItem["day"],
                                  begin: begin as ScheduleTableItem["begin"],
                                  end: end as ScheduleTableItem["end"],
                                  title: course.subjectName,
                                  location: course.roomName ?? undefined,
                                  kind: "attendance",
                                  raw: course,
                              },
                          ];
                }),
            );
            if (res) {
                setTotalWeeks(res.totalWeeks);
                setSchedule(items ?? []);
            }
        } finally {
            setLoading(false);
        }
    }

    // 3. 依赖联动：当 week 或学期改变时，自动重新 fetch
    useEffect(() => {
        fetchSchedule();
    }, [week, year, term, ready, authState]);

    // 4. 将 UI 需要的数据全部透出
    return {
        // 数据状态
        schedule: displaySchedule,
        loading,

        week,
        setWeek,
        totalWeeks,

        // 手动刷新
        refresh: fetchSchedule,

        // 把 UI 可能会用到的学期信息透出给组件
        year,
        term,
        startDay: startDayInfo.startDay, // 用于计算“第几周”
    };
}
