import {useCallback, useEffect, useMemo, useRef, useState} from "react";
import {useFocusEffect} from "@react-navigation/native";
import {emptyClassroomRepo} from "../repo/EmptyClassroomRepo";
import {useCacheRunnerStore} from "../stores/cacheRunnerStore";
import {useSelectionStore} from "../stores/selectionStore";
import type {FreePeriodRow, FreeRunItem, LogicalTerm, RoomRecord, WeekSnapshot} from "../type";
import {MAX_WEEKS} from "../utils/constants";
import {buildFreeRuns} from "../utils/freeRuns";
import {clampWeek} from "../utils/terms";

/** TimeScheduleView 的 offscreenPageLimit=2，只预取当前周前后各 2 周。 */
const WINDOW_RADIUS = 2;

export type UseEmptyClassroomOverviewParams = {
    year: number;
    term: LogicalTerm;
    roomId: number | null;
    /** 当前 pager 周次（1–20），决定 slots 预取窗口。 */
    activeWeek: number;
    /** 为 false 时不读库；缺省 true。 */
    enabled?: boolean;
};

export type EmptyClassroomOverview = {
    /** 该学期所有已缓存周（completedDays>0）。 */
    snapshots: WeekSnapshot[];
    /** week -> snapshot，便于按周取状态。 */
    snapshotByWeek: Map<number, WeekSnapshot>;
    /** 当前选中的教室元数据；未选择或已不存在时为 null。 */
    room: RoomRecord | null;
    /** 已加载窗口内所有周合并后的连续空闲段。 */
    runs: FreeRunItem[];
    /** 已真正查询过 slots 的周集合；用于区分「加载中」和「已加载但无空闲」。 */
    loadedWeeks: Set<number>;
    loading: boolean;
    error: string | null;
    reload: () => void;
};

type SlotsCache = {
    key: string;
    slotsByWeek: Map<number, FreePeriodRow[]>;
    loadedWeeks: Set<number>;
};

const EMPTY_CACHE: SlotsCache = {
    key: "",
    slotsByWeek: new Map(),
    loadedWeeks: new Set(),
};

function getWindowWeeks(week: number): number[] {
    const current = clampWeek(week);
    const weeks: number[] = [];
    const begin = Math.max(1, current - WINDOW_RADIUS);
    const end = Math.min(MAX_WEEKS, current + WINDOW_RADIUS);
    for (let value = begin; value <= end; value += 1) weeks.push(value);
    return weeks;
}

function toMessage(cause: unknown): string {
    return cause instanceof Error ? cause.message : String(cause);
}

/**
 * 作用：第一屏数据源。加载学期快照与当前教室元数据，并按 activeWeek ±2 懒加载 slots。
 * 入参：year/term/roomId/activeWeek；enabled=false 时清空并不读库。
 * 出参：snapshots、snapshotByWeek、room、runs、loadedWeeks、loading、error、reload。
 * 修改注意：
 * - 不要一次读取 20 周 slots；窗口外由 pager 切换 activeWeek 后再补。
 * - 教室在当前学期没有 slots 是合法状态（可能本学期未缓存），不应清空选择；
 *   只有 getRoom 返回 null（数据库重建）才调用 selectionStore.setRoom(null)。
 */
export function useEmptyClassroomOverview(params: UseEmptyClassroomOverviewParams): EmptyClassroomOverview {
    const {year, term, roomId, activeWeek, enabled = true} = params;
    const revision = useCacheRunnerStore(s => s.revision);

    const [focusToken, setFocusToken] = useState(0);
    const [reloadToken, setReloadToken] = useState(0);
    const [snapshots, setSnapshots] = useState<WeekSnapshot[]>([]);
    const [room, setRoom] = useState<RoomRecord | null>(null);
    const [cache, setCache] = useState<SlotsCache>(EMPTY_CACHE);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const cacheRef = useRef<SlotsCache>(EMPTY_CACHE);
    const requestSeq = useRef(0);
    const focusSeenRef = useRef(false);

    const effectiveRoomId = Number.isInteger(roomId) && (roomId as number) > 0 ? (roomId as number) : null;
    const canLoad = enabled && Number.isInteger(year) && year > 0 && (term === 1 || term === 2);
    // focus/reload 也纳入 key：重新进入页面时清空窗口缓存并重新读取 slots。
    const cacheKey = `${year}|${term}|${effectiveRoomId ?? "none"}|${revision}|${focusToken}|${reloadToken}`;

    useFocusEffect(
        useCallback(() => {
            if (focusSeenRef.current) setFocusToken(value => value + 1);
            else focusSeenRef.current = true;
        }, []),
    );

    useEffect(() => {
        if (!canLoad) {
            requestSeq.current += 1;
            cacheRef.current = EMPTY_CACHE;
            setCache(EMPTY_CACHE);
            setSnapshots([]);
            setRoom(null);
            setLoading(false);
            setError(null);
            return;
        }

        const seq = requestSeq.current + 1;
        requestSeq.current = seq;
        let active = true;
        const isCurrent = () => active && requestSeq.current === seq;

        if (cacheRef.current.key !== cacheKey) {
            const next: SlotsCache = {key: cacheKey, slotsByWeek: new Map(), loadedWeeks: new Set()};
            cacheRef.current = next;
            setCache(next);
        }

        setLoading(true);
        setError(null);

        (async () => {
            try {
                const nextSnapshots = await emptyClassroomRepo.listWeeks(year, term);
                if (!isCurrent()) return;
                setSnapshots(nextSnapshots);

                let nextRoom: RoomRecord | null = null;
                if (effectiveRoomId !== null) {
                    nextRoom = await emptyClassroomRepo.getRoom(effectiveRoomId);
                    if (!isCurrent()) return;
                    setRoom(nextRoom);

                    if (!nextRoom) {
                        // 只有 DB 里确实不存在该教室时才清空选择；当前学期无 slots 不清空。
                        const selection = useSelectionStore.getState();
                        if (selection.roomId === effectiveRoomId) selection.setRoom(null);
                        const next: SlotsCache = {key: cacheKey, slotsByWeek: new Map(), loadedWeeks: new Set()};
                        cacheRef.current = next;
                        setCache(next);
                        return;
                    }
                } else {
                    setRoom(null);
                }

                if (nextRoom && effectiveRoomId !== null) {
                    const cachedWeeks = new Set(
                        nextSnapshots.filter(snapshot => snapshot.completedDays > 0).map(snapshot => snapshot.week),
                    );
                    const weeksToLoad = getWindowWeeks(activeWeek).filter(
                        week => cachedWeeks.has(week) && !cacheRef.current.loadedWeeks.has(week),
                    );

                    if (weeksToLoad.length > 0) {
                        const rows = await emptyClassroomRepo.getRoomWeekSlots(
                            year,
                            term,
                            effectiveRoomId,
                            weeksToLoad,
                        );
                        if (!isCurrent()) return;

                        const nextSlots = new Map(cacheRef.current.slotsByWeek);
                        const nextLoaded = new Set(cacheRef.current.loadedWeeks);
                        for (const week of weeksToLoad) {
                            nextSlots.set(
                                week,
                                rows.filter(row => row.week === week),
                            );
                            nextLoaded.add(week);
                        }
                        cacheRef.current = {key: cacheKey, slotsByWeek: nextSlots, loadedWeeks: nextLoaded};
                        setCache(cacheRef.current);
                    }
                }
            } catch (cause) {
                if (isCurrent()) setError(toMessage(cause));
            } finally {
                if (isCurrent()) setLoading(false);
            }
        })();

        return () => {
            active = false;
        };
    }, [canLoad, cacheKey, year, term, effectiveRoomId, activeWeek]);

    const activeCache = cache.key === cacheKey ? cache : EMPTY_CACHE;

    const snapshotByWeek = useMemo(() => new Map(snapshots.map(snapshot => [snapshot.week, snapshot])), [snapshots]);

    const runs = useMemo(() => {
        const rows: FreePeriodRow[] = [];
        for (const weekRows of activeCache.slotsByWeek.values()) rows.push(...weekRows);
        return buildFreeRuns(rows);
    }, [activeCache]);

    const reload = useCallback(() => setReloadToken(value => value + 1), []);

    return {
        snapshots,
        snapshotByWeek,
        room,
        runs,
        loadedWeeks: activeCache.loadedWeeks,
        loading,
        error,
        reload,
    };
}
