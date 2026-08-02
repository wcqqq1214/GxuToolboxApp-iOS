import {SchoolTermValue} from "@/type/global.ts";
import {useEffect, useState} from "react";
import {fetchStartDay, getCurrentStartDay, getSyncStartDay, saveToDB} from "@/features/courseSchedule/repo/startDay.ts";
import dayjs, {Dayjs} from "dayjs";
import moment from "moment";

// 正在刷新
let isSyncing = false;

export function useStartDay(year?: number, term?: SchoolTermValue) {
    const cachedTerm = getSyncStartDay();

    const [startDay, setStartDay] = useState((): Dayjs => (cachedTerm ? dayjs(cachedTerm.day) : dayjs("2025-09-08")));
    const fetch = async () => {
        if (isSyncing) return;
        isSyncing = true;

        try {
            const remoteTerms = await fetchStartDay();

            if (remoteTerms && remoteTerms.length > 0) {
                const now = dayjs();

                // 先按开学日期升序排列 (保证时间线从过去到未来)
                const sortedTerms = [...remoteTerms].sort((a, b) => dayjs(a.day).valueOf() - dayjs(b.day).valueOf());

                // 清理所有的 is_current 标记
                sortedTerms.forEach(t => (t.is_current = false));

                // 找出真正的 currentTerm
                // 逻辑：找到第一个其结束时间晚于现在的学期。
                // 因为是按时间排序的，第一个满足这个条件的，要么是正在进行中的学期，要么是即将到来的下个学期（因为此时处于假期，上个学期已经结束了）
                let cur = false;
                for (const t of sortedTerms) {
                    const endDate = dayjs(t.day).add(t.week, "week");

                    if (now.isBefore(endDate, "day")) {
                        t.is_current = true;
                        cur = true;
                        break;
                    }
                }

                // 如果所有学期都结束了（比如用户在毕业后打开APP，或者后端没给未来的数据）
                // 那就把列表里最后一个（最新的）学期作为当前学期
                if (!cur && sortedTerms.length > 0) {
                    sortedTerms[sortedTerms.length - 1].is_current = true;
                }

                // 存进数据库
                await saveToDB(sortedTerms);
            }
        } catch (e) {
            console.error("Fetch start day error:", e);
        } finally {
            isSyncing = false;
        }
    };

    useEffect(() => {
        const init = async () => {
            try {
                let currentTerm = await getCurrentStartDay();

                const needFetch =
                    !currentTerm ||
                    dayjs().isAfter(dayjs(currentTerm.day).add(currentTerm.week, "week").subtract(1, "day"), "day");

                if (currentTerm && !cachedTerm) {
                    setStartDay(dayjs(currentTerm.day));
                }

                if (needFetch) {
                    await fetch();
                    currentTerm = await getCurrentStartDay();
                    if (currentTerm) {
                        setStartDay(dayjs(currentTerm.day));
                    }
                }
            } catch (error) {
                console.error("同步学期数据失败:", error);
            } finally {
                isSyncing = false;
            }
        };

        init();
    }, []);

    // 暂时兼容一下moment
    return moment(startDay.format());
}
