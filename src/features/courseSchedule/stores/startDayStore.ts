/**
 * 提供mmkv读写开学日期的接口
 */
import {TermStartDay} from "@/features/courseSchedule/repo/startDay.ts";
import {create} from "zustand/react";
import {mmkv} from "@/store/mmkv.ts";

interface StartDayStore {
    terms: TermStartDay[];
    setTerms: (terms: TermStartDay[]) => void;
}

/**
 * 在React hook里：const terms = useStartDayStore(s => s.terms);
 */
export const useStartDayStore = create<StartDayStore>()(set => ({
    terms: mmkv.getObject<TermStartDay[]>("termStartDay") ?? [],
    setTerms: terms => {
        mmkv.set("termStartDay", terms);
        set({terms});
    },
}));

/**
 * 非React组件也能用的同步读取
 */
export const getStartDay = (year?: number, term?: number): TermStartDay | null => {
    const {terms} = useStartDayStore.getState();
    if (!terms.length) {
        return null;
    }
    if (year && term) {
        return terms.find(t => t.year === year && t.term === term) ?? null;
    }
    return terms.find(t => t.is_current) ?? null;
};
