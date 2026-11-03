import dayjs from "dayjs";
import moment, {type Moment} from "moment";
import type {SchoolTermValue} from "@/type/global.ts";
import {type TermStartDay} from "@/features/courseSchedule/repo/startDay.ts";
import {useStartDayStore} from "@/features/courseSchedule/stores/startDayStore.ts";
import {useMemo} from "react";

export interface TermInfo {
    startDay: Moment;
    weekCount: number;
    isStarted: boolean;
    isEnded: boolean;
    year: number;
    term: number;
    /**
     * @Deprecated 由于早已准备好，所以永远返回true
     */
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

/**
 * 读取学期开学信息。传入 year/term 时查询明确学期；不传时返回当前或下一个学期。
 * term 同时兼容旧教务码 3/12 与逻辑码 1/2，向外始终返回逻辑码。
 * 【read only】不应在这里写入信息。
 */
export function useStartDay(year?: number, term?: SchoolTermValue | string): TermInfo {
    const logicalTerm = toLogicalTerm(term);

    const terms = useStartDayStore(s => s.terms);

    // 计划要返回的就是这个学期
    let target;
    if (year && logicalTerm) {
        target = terms.find(t => t.year === year && t.term === logicalTerm);
    } else {
        target = terms.find(t => t.is_current);
    }

    return useMemo(
        () =>
            (target ?
                toTermInfo(target) :
                emptyTermInfo(year, term)),
        [target, year, logicalTerm, term]);
}
