import {backendHttp} from "@/features/backend/api";
import dayjs from "dayjs";
import {useStartDayStore} from "@/features/courseSchedule/stores/startDayStore.ts";

export interface TermStartDay {
    year: number;
    term: number;
    day: string;
    week: number;
    is_current: boolean;
}

let pendingSync: Promise<void> | null = null;

export async function fetchStartDay(): Promise<TermStartDay[]> {
    const res = await backendHttp.get("/jw/profile/startDay");
    return res.data.data;
}

function normalizeTerms(remote: TermStartDay[]): TermStartDay[] {
    const now = dayjs();
    const sorted = [...remote]
        .sort((a, b) => dayjs(a.day).valueOf() - dayjs(b.day).valueOf())
        .map(term => ({...term, is_current: false}));
    const current = sorted.find(term => now.isBefore(dayjs(term.day).add(term.week, "week"), "day"));
    (current ?? sorted[sorted.length - 1]).is_current = true;
    return sorted;
}

/**
 * 检查本地MMKV里缓存的开学日期是否有效
 * @param terms
 */
const isLocalValid = (terms: TermStartDay[]): boolean => {
    if (!terms.length) {
        return false;
    }
    const current = terms.find(t => t.is_current);
    if (!current) {
        return false;
    }
    // 学期最后一天是开学日+week-1天，如果当前学期没结束就有效
    return !dayjs().isAfter(dayjs(current.day).add(current.week, "week").subtract(1, "day"), "day");
};

/**
 * 确保开学日期已同步：
 * - 本地有效时直接跳过
 * - 本地为空或当前学期已结束时，拉取后端并写回Store
 */
export const ensureStartDay = async (force = false) => {
    const {terms, setTerms} = useStartDayStore.getState();

    if (!force && isLocalValid(terms)) {
        return;
    }
    if (pendingSync) {
        return pendingSync;
    }
    pendingSync = (async () => {
        const res = await fetchStartDay();
        if (!res?.length) {
            return;
        }
        const normalized = normalizeTerms(res);
        setTerms(normalized);
    })();

    try {
        await pendingSync;
    } finally {
        pendingSync = null;
    }
};
