import {useEffect, useState} from "react";
import dayjs from "dayjs";
import moment, {type Moment} from "moment";
import type {SchoolTermValue} from "@/type/global.ts";
import {
    fetchStartDay,
    getCurrentStartDay,
    getStartDay,
    getSyncStartDay,
    saveToDB,
    type TermStartDay,
} from "@/features/courseSchedule/repo/startDay.ts";

let pendingSync: Promise<void> | null = null;

export interface TermInfo {
    startDay: Moment;
    weekCount: number;
    isStarted: boolean;
    isEnded: boolean;
    year: number;
    term: number;
    ready: boolean;
}

function toLogicalTerm(term?: SchoolTermValue | string): 1 | 2 | null {
    if (term === 1 || term === 3 || term === "1" || term === "3") return 1;
    if (term === 2 || term === 12 || term === "2" || term === "12") return 2;
    return null;
}

function toTermInfo(term: TermStartDay): TermInfo {
    const startDay = dayjs(term.day);
    const endDay = startDay.add(term.week, "week");
    const now = dayjs();

    return {
        startDay: moment(term.day),
        weekCount: term.week,
        isStarted: !now.isBefore(startDay, "day"),
        isEnded: now.isAfter(endDay, "day"),
        year: term.year,
        term: term.term,
        ready: true,
    };
}

function emptyTermInfo(year?: number, term?: SchoolTermValue | string): TermInfo {
    return {
        // 保持旧页面在数据尚未就绪时仍能获得 Moment；ready=false 表示该日期不可作为业务判断依据。
        startDay: moment("2026-09-07"),
        weekCount: 0,
        isStarted: false,
        isEnded: false,
        year: year ?? 0,
        term: toLogicalTerm(term) ?? 0,
        ready: false,
    };
}

async function syncTerms(): Promise<void> {
    if (pendingSync) return pendingSync;

    pendingSync = (async () => {
        const remoteTerms = await fetchStartDay();
        if (!remoteTerms?.length) return;

        const now = dayjs();
        const sortedTerms = [...remoteTerms].sort((a, b) => dayjs(a.day).valueOf() - dayjs(b.day).valueOf());
        sortedTerms.forEach(term => (term.is_current = false));

        const current = sortedTerms.find(term => now.isBefore(dayjs(term.day).add(term.week, "week"), "day"));
        (current ?? sortedTerms[sortedTerms.length - 1]).is_current = true;
        await saveToDB(sortedTerms);
    })();

    try {
        await pendingSync;
    } catch (cause) {
        console.error("同步学期开学信息失败", cause);
    } finally {
        pendingSync = null;
    }
}

/**
 * 读取学期开学信息。传入 year/term 时查询明确学期；不传时返回当前或下一个学期。
 * term 同时兼容旧教务码 3/12 与逻辑码 1/2，向外始终返回逻辑码。
 */
export function useStartDay(year?: number, term?: SchoolTermValue | string): TermInfo {
    const logicalTerm = toLogicalTerm(term);
    const cachedCurrent = getSyncStartDay();
    const [termInfo, setTermInfo] = useState<TermInfo>(() => {
        const cacheMatches =
            cachedCurrent &&
            (!year || !logicalTerm || (cachedCurrent.year === year && cachedCurrent.term === logicalTerm));
        return cacheMatches ? toTermInfo(cachedCurrent) : emptyTermInfo(year, term);
    });

    useEffect(() => {
        let active = true;

        const readTarget = () => (year && logicalTerm ? getStartDay(year, logicalTerm) : getCurrentStartDay());

        const initialize = async () => {
            let target = await readTarget();
            if (active && target) setTermInfo(toTermInfo(target));

            const current = await getCurrentStartDay();
            const currentEnded =
                current && dayjs().isAfter(dayjs(current.day).add(current.week, "week").subtract(1, "day"), "day");

            if (!target || !current || currentEnded) {
                await syncTerms();
                target = await readTarget();
                if (active && target) setTermInfo(toTermInfo(target));
            }
        };

        initialize().catch(cause => {
            console.error("读取学期开学信息失败", cause);
        });

        return () => {
            active = false;
        };
    }, [logicalTerm, term, year]);

    return termInfo;
}
