import {create} from "zustand/react";
import {useShallow} from "zustand/react/shallow";
import {useCallback, useEffect, useMemo} from "react";
import moment from "moment";
import {mmkv} from "@/store/mmkv.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {getWeekOfDate} from "@/features/courseSchedule/utils/weekOfDate.ts";
import type {LogicalTerm} from "../type";
import {MMKV_SELECTION_KEY} from "../utils/constants";
import {clampWeek, toLogicalTerm} from "../utils/terms";

export type SelectionState = {
    /** 学年，例如 2026。 */
    year: number;
    /** 逻辑学期：1（秋季）/ 2（春季）。 */
    term: LogicalTerm;
    /** 教学周，1–20。 */
    week: number;
    /** 选中的教室 id；未选择时为 null。 */
    roomId: number | null;
};

export type SelectionDefaults = Omit<SelectionState, "roomId">;

/** 对外暴露的选择快照；hydrated 表示已从 MMKV 恢复或已应用默认值。 */
export type SelectionSnapshot = SelectionState & {hydrated: boolean};

export type SelectionActions = {
    /**
     * 作用：仅在没有任何合法持久化选择时应用默认值。
     * 修改注意：一旦初始化成功（持久化值合法或默认值已应用）就永久 no-op，
     * 避免 useStartDay 后续就绪时覆盖用户已经调整的周次/教室。
     */
    init: (defaults: SelectionDefaults) => void;
    /**
     * 作用：切换学期；值相同直接 no-op，变化时清空教室并重置周次。
     * 入参：
     * - year/term：兼容 number 与字符串（UnTermSelector 传 "3"/"12"）；
     * - week：调用方可传当前周；缺省为第 1 周。
     */
    setTerm: (year: number | string, term: number | string, week?: number) => void;
    /** 作用：设置教学周，自动夹到 1–20。 */
    setWeek: (week: number) => void;
    /** 作用：设置教室；传 null 清空，非法值忽略。 */
    setRoom: (roomId: number | null) => void;
};

export type SelectionStoreState = SelectionSnapshot & SelectionActions;

const EMPTY_SELECTION: SelectionState = {year: 0, term: 1, week: 1, roomId: null};

function toYear(value: string | number | undefined): number | null {
    if (value === undefined) return null;
    const year = typeof value === "number" ? value : Number(value);
    if (!Number.isInteger(year) || year <= 0) return null;
    return year;
}

function toSafeLogicalTerm(value: string | number | undefined): LogicalTerm | null {
    if (value === undefined) return null;
    try {
        return toLogicalTerm(value);
    } catch {
        return null;
    }
}

function normalizeRoomId(value: unknown): number | null | undefined {
    if (value === null) return null;
    if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) return undefined;
    return value;
}

/** 读取并校验 MMKV 中的选择；任一字段损坏就整体忽略。 */
function readPersistedSelection(): SelectionState | null {
    const raw = mmkv.getObject<Record<string, unknown>>(MMKV_SELECTION_KEY);
    if (!raw) return null;

    const year = toYear(raw.year as string | number | undefined);
    const term = raw.term === 1 || raw.term === 2 ? raw.term : null;
    const week = typeof raw.week === "number" && Number.isInteger(raw.week) ? raw.week : null;
    const roomId = normalizeRoomId(raw.roomId);
    if (year === null || term === null || week === null || week < 1 || week > 20) return null;
    if (roomId === undefined) return null;

    return {year, term, week, roomId};
}

function persistSelection(selection: SelectionState): void {
    mmkv.set(MMKV_SELECTION_KEY, selection);
}

const persistedSelection = readPersistedSelection();
/** 持久化值合法或默认值已应用后置位，init 不再覆盖用户选择。 */
let initialized = persistedSelection !== null;

export const useSelectionStore = create<SelectionStoreState>((set, get) => ({
    ...(persistedSelection ?? EMPTY_SELECTION),
    hydrated: persistedSelection !== null,

    init: defaults => {
        if (initialized) return;

        const year = toYear(defaults.year);
        const term = toSafeLogicalTerm(defaults.term);
        if (year === null || term === null) return;

        initialized = true;
        const next: SelectionState = {
            year,
            term,
            week: clampWeek(defaults.week),
            roomId: null,
        };
        set({...next, hydrated: true});
        persistSelection(next);
    },

    setTerm: (year, term, week) => {
        const nextYear = toYear(year);
        const nextTerm = toSafeLogicalTerm(term);
        if (nextYear === null || nextTerm === null) return;

        const current = get();
        if (current.year === nextYear && current.term === nextTerm) return;

        const next: SelectionState = {
            year: nextYear,
            term: nextTerm,
            week: clampWeek(week ?? 1),
            roomId: null,
        };
        set(next);
        persistSelection(next);
    },

    setWeek: week => {
        const next = clampWeek(week);
        if (next === get().week) return;
        set({week: next});
        persistSelection(get());
    },

    setRoom: roomId => {
        const next = normalizeRoomId(roomId);
        if (next === undefined) return;
        if (next === get().roomId) return;
        set({roomId: next});
        persistSelection(get());
    },
}));

/**
 * 作用：读取当前选择与 hydrated 标记。
 * 出参：SelectionSnapshot；year 为 0 表示尚未初始化。
 */
export function useSelection(): SelectionSnapshot {
    return useSelectionStore(
        useShallow(state => ({
            year: state.year,
            term: state.term,
            week: state.week,
            roomId: state.roomId,
            hydrated: state.hydrated,
        })),
    );
}

/** 作用：返回稳定的选择 action；组件只需订阅一次引用。 */
export function useSelectionActions(): SelectionActions {
    return useSelectionStore(
        useShallow(state => ({
            init: state.init,
            setTerm: state.setTerm,
            setWeek: state.setWeek,
            setRoom: state.setRoom,
        })),
    );
}

/**
 * 作用：计算首次进入时的默认学期/周次。
 * 优先级：useStartDay() 的当前/下一学期；未就绪时回退到用户配置的 jw.year/term。
 * 周次：该学期已开学时取当前教学周，否则第 1 周。
 * 出参：无有效日期来源时返回 null（调用方应等待下一次渲染）。
 */
export function useSelectionDefaults(): SelectionDefaults | null {
    const {year, term, isStarted, startDay, ready} = useStartDay();
    const {store} = useUserConfig();
    const configYear = store(s => s.jw.year);
    const configTerm = store(s => s.jw.term);

    return useMemo(() => {
        if (ready && year > 0 && (term === 1 || term === 2)) {
            return {
                year,
                term: term as LogicalTerm,
                week: isStarted ? clampWeek(getWeekOfDate(moment(), startDay)) : 1,
            };
        }

        const fallbackYear = toYear(configYear);
        const fallbackTerm = toSafeLogicalTerm(configTerm);
        if (fallbackYear === null || fallbackTerm === null) return null;
        return {year: fallbackYear, term: fallbackTerm, week: 1};
    }, [ready, year, term, isStarted, startDay, configYear, configTerm]);
}

/**
 * 作用：在屏幕挂载时初始化 selectionStore。
 * 只在 store 尚未从 MMKV 恢复合法值且从未初始化过时生效；
 * defaults 未就绪（null）时什么都不做。
 */
export function useSelectionInit(): void {
    const defaults = useSelectionDefaults();
    const init = useSelectionStore(s => s.init);

    useEffect(() => {
        if (defaults) init(defaults);
    }, [defaults, init]);
}

/**
 * 作用：供 UnTermSelector 使用的学期切换回调。
 * 切到当前学期时沿用当前教学周（已开学）或第 1 周；切到其他学期固定第 1 周。
 * 入参 year/term 兼容 UnTermSelector 的字符串学期码 "3"/"12"。
 */
export function useSelectionTermSwitcher(): (year: number | string, term: number | string) => void {
    const {year: currentYear, term: currentTerm, isStarted, startDay, ready} = useStartDay();
    const setTerm = useSelectionStore(s => s.setTerm);

    return useCallback(
        (year, term) => {
            const nextYear = toYear(year);
            const nextTerm = toSafeLogicalTerm(term);
            if (nextYear === null || nextTerm === null) return;

            const isCurrentTerm = ready && currentYear === nextYear && currentTerm === nextTerm;
            const week = isCurrentTerm && isStarted ? clampWeek(getWeekOfDate(moment(), startDay)) : 1;
            setTerm(nextYear, nextTerm, week);
        },
        [currentYear, currentTerm, isStarted, startDay, ready, setTerm],
    );
}
