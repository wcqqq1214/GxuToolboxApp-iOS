import {useCallback, useEffect, useMemo, useRef, useState} from "react";
import moment from "moment";
import {emptyClassroomRepo} from "../repo/EmptyClassroomRepo";
import {useCacheRunnerStore} from "../stores/cacheRunnerStore";
import type {
    LogicalTerm,
    RoomAvailabilityResult,
    TimeQuerySortDirection,
    TimeQuerySortMode,
    WeekSnapshot,
} from "../type";
import {AVAILABLE_ROOM_PAGE_SIZE, DAYS, PERIODS} from "../utils/constants";
import {buildRoomAvailabilityResults, sortRoomAvailabilityResults} from "../utils/timeQuery";
import {clampWeek} from "../utils/terms";

const FILTER_DEBOUNCE_MS = 350;

type QueryFilters = {
    week: number | null;
    day: number | null;
    buildings: string[];
    roomIds: number[];
    keyword: string;
    startPeriod: number;
    endPeriod: number;
};

export type UseTimeClassroomQueryParams = {
    year: number;
    term: LogicalTerm;
    /** 当前教学周；只在首次加载或缓存被删除时用于挑选最近的已缓存周。 */
    preferredWeek: number;
    enabled?: boolean;
};

export type TimeClassroomQueryState = {
    snapshots: WeekSnapshot[];
    selectedWeek: number | null;
    selectedDay: number | null;
    completedDays: number[];
    buildingFilters: string[];
    roomIds: number[];
    keyword: string;
    startPeriod: number;
    endPeriod: number;
    sortMode: TimeQuerySortMode;
    sortDirection: TimeQuerySortDirection;
    results: RoomAvailabilityResult[];
    totalCount: number;
    hasMore: boolean;
    loading: boolean;
    loadingMore: boolean;
    error: string | null;
    setDay: (day: number) => void;
    setBuildings: (buildings: string[]) => void;
    setRoomIds: (roomIds: number[]) => void;
    setKeyword: (keyword: string) => void;
    setPeriodRange: (startPeriod: number, endPeriod: number) => void;
    setSortMode: (mode: TimeQuerySortMode) => void;
    toggleSortDirection: () => void;
    loadMore: () => void;
    reload: () => void;
};

function toMessage(cause: unknown): string {
    return cause instanceof Error ? cause.message : String(cause);
}

function clampPeriod(period: number): number {
    if (!Number.isFinite(period)) return 1;
    return Math.min(PERIODS, Math.max(1, Math.trunc(period)));
}

function closestCachedWeek(snapshots: WeekSnapshot[], preferredWeek: number): number | null {
    if (snapshots.length === 0) return null;
    const target = clampWeek(preferredWeek);
    return snapshots.reduce((closest, snapshot) => {
        const currentDistance = Math.abs(snapshot.week - target);
        const closestDistance = Math.abs(closest.week - target);
        if (currentDistance < closestDistance) return snapshot;
        if (currentDistance === closestDistance && snapshot.week < closest.week) return snapshot;
        return closest;
    }, snapshots[0]).week;
}

/**
 * 作用：按已缓存教学日和节次范围查询空闲教室，并管理筛选、防抖和排序状态。
 * 入参：year/term 共用当前学期；preferredWeek 是现有按教室页面的周次，仅在初始时优先选择。
 * 出参：筛选状态、命中结果、加载/错误状态及稳定 action。
 * 修改注意：时间查询拥有独立周/日期，不写 selectionStore；缓存 revision 变化时整条链路重新读取。
 */
export function useTimeClassroomQuery(params: UseTimeClassroomQueryParams): TimeClassroomQueryState {
    const {year, term, preferredWeek, enabled = true} = params;
    const revision = useCacheRunnerStore(state => state.revision);

    const [snapshots, setSnapshots] = useState<WeekSnapshot[]>([]);
    const [selectedWeek, setSelectedWeek] = useState<number | null>(null);
    const [selectedDay, setSelectedDay] = useState<number | null>(null);
    const [completedDays, setCompletedDays] = useState<number[]>([]);
    const [buildingFilters, setBuildingFiltersState] = useState<string[]>([]);
    const [roomIds, setRoomIdsState] = useState<number[]>([]);
    const [keyword, setKeyword] = useState("");
    const [startPeriod, setStartPeriodState] = useState(1);
    const [endPeriod, setEndPeriodState] = useState(PERIODS);
    const [sortMode, setSortMode] = useState<TimeQuerySortMode>("default");
    const [sortDirection, setSortDirection] = useState<TimeQuerySortDirection>("desc");
    const [rawResults, setRawResults] = useState<RoomAvailabilityResult[]>([]);
    const [catalogLoading, setCatalogLoading] = useState(false);
    const [daysLoading, setDaysLoading] = useState(false);
    const [queryLoading, setQueryLoading] = useState(false);
    const [loadingMore, setLoadingMore] = useState(false);
    const [totalCount, setTotalCount] = useState(0);
    const [hasMore, setHasMore] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [reloadToken, setReloadToken] = useState(0);
    const [debouncedFilters, setDebouncedFilters] = useState<QueryFilters>({
        week: null,
        day: null,
        buildings: [],
        roomIds: [],
        keyword: "",
        startPeriod: 1,
        endPeriod: PERIODS,
    });

    const selectedWeekRef = useRef<number | null>(null);
    const selectedDayRef = useRef<number | null>(null);
    const catalogScopeRef = useRef("");
    const catalogRequestSeq = useRef(0);
    const daysRequestSeq = useRef(0);
    const queryRequestSeq = useRef(0);
    const pageRef = useRef(1);
    const loadingMoreRef = useRef(false);

    const updateWeek = useCallback((week: number | null) => {
        selectedWeekRef.current = week;
        setSelectedWeek(week);
    }, []);

    const updateDay = useCallback((day: number | null) => {
        selectedDayRef.current = day;
        setSelectedDay(day);
    }, []);

    const canLoad = enabled && Number.isInteger(year) && year > 0 && (term === 1 || term === 2);

    useEffect(() => {
        if (!canLoad) {
            catalogScopeRef.current = "";
            catalogRequestSeq.current += 1;
            daysRequestSeq.current += 1;
            queryRequestSeq.current += 1;
            setSnapshots([]);
            updateWeek(null);
            updateDay(null);
            setCompletedDays([]);
            setBuildingFiltersState([]);
            setRoomIdsState([]);
            setRawResults([]);
            setCatalogLoading(false);
            setDaysLoading(false);
            setQueryLoading(false);
            setError(null);
            return;
        }

        const scope = `${year}|${term}`;
        if (catalogScopeRef.current !== scope) {
            catalogScopeRef.current = scope;
            setSnapshots([]);
            updateWeek(null);
            updateDay(null);
            setCompletedDays([]);
            setRawResults([]);
            setBuildingFiltersState([]);
            setRoomIdsState([]);
        }

        const seq = catalogRequestSeq.current + 1;
        catalogRequestSeq.current = seq;
        let active = true;
        setCatalogLoading(true);
        setError(null);

        emptyClassroomRepo
            .listWeeks(year, term)
            .then(rows => {
                if (!active || catalogRequestSeq.current !== seq) return;
                setSnapshots(rows);
                const currentWeek = selectedWeekRef.current;
                const keepCurrent = currentWeek !== null && rows.some(snapshot => snapshot.week === currentWeek);
                const nextWeek = keepCurrent ? currentWeek : closestCachedWeek(rows, preferredWeek);
                if (nextWeek !== currentWeek) updateDay(null);
                updateWeek(nextWeek);
            })
            .catch(cause => {
                if (!active || catalogRequestSeq.current !== seq) return;
                setSnapshots([]);
                updateWeek(null);
                updateDay(null);
                setCompletedDays([]);
                setRawResults([]);
                setError(toMessage(cause));
            })
            .finally(() => {
                if (active && catalogRequestSeq.current === seq) setCatalogLoading(false);
            });

        return () => {
            active = false;
        };
    }, [canLoad, preferredWeek, reloadToken, revision, term, updateDay, updateWeek, year]);

    useEffect(() => {
        if (!canLoad || selectedWeek === null) {
            daysRequestSeq.current += 1;
            setCompletedDays([]);
            updateDay(null);
            setDaysLoading(false);
            return;
        }

        const seq = daysRequestSeq.current + 1;
        daysRequestSeq.current = seq;
        let active = true;
        setDaysLoading(true);
        setError(null);

        emptyClassroomRepo
            .getCompletedDays(year, term, selectedWeek)
            .then(days => {
                if (!active || daysRequestSeq.current !== seq) return;
                setCompletedDays(days);

                const currentDay = selectedDayRef.current;
                const keepCurrent = currentDay !== null && days.includes(currentDay);
                const today = moment().isoWeekday();
                const nextDay = keepCurrent
                    ? currentDay
                    : selectedWeek === clampWeek(preferredWeek) && days.includes(today)
                      ? today
                      : (days[0] ?? null);
                updateDay(nextDay);
            })
            .catch(cause => {
                if (!active || daysRequestSeq.current !== seq) return;
                setCompletedDays([]);
                updateDay(null);
                setRawResults([]);
                setError(toMessage(cause));
            })
            .finally(() => {
                if (active && daysRequestSeq.current === seq) setDaysLoading(false);
            });

        return () => {
            active = false;
        };
    }, [canLoad, preferredWeek, reloadToken, revision, selectedWeek, term, updateDay, updateWeek, year]);

    const currentFilters: QueryFilters = useMemo(
        () => ({
            week: selectedWeek,
            day: selectedDay,
            buildings: buildingFilters,
            roomIds,
            keyword: keyword.trim(),
            startPeriod,
            endPeriod,
        }),
        [buildingFilters, endPeriod, keyword, roomIds, selectedDay, selectedWeek, startPeriod],
    );
    const currentFilterKey = JSON.stringify(currentFilters);
    const debouncedFilterKey = JSON.stringify(debouncedFilters);

    useEffect(() => {
        const timer = setTimeout(() => setDebouncedFilters(currentFilters), FILTER_DEBOUNCE_MS);
        return () => clearTimeout(timer);
    }, [currentFilters]);

    useEffect(() => {
        queryRequestSeq.current += 1;
        pageRef.current = 1;
        loadingMoreRef.current = false;
        setRawResults([]);
        setQueryLoading(false);
        setLoadingMore(false);
        setTotalCount(0);
        setHasMore(false);
        setError(null);
    }, [currentFilterKey, revision, sortDirection, sortMode]);

    useEffect(() => {
        const filters = debouncedFilters;
        if (
            !canLoad ||
            filters.week === null ||
            filters.day === null ||
            completedDays.length === 0 ||
            !completedDays.includes(filters.day)
        ) {
            queryRequestSeq.current += 1;
            setRawResults([]);
            setQueryLoading(false);
            return;
        }

        const seq = queryRequestSeq.current + 1;
        queryRequestSeq.current = seq;
        pageRef.current = 1;
        loadingMoreRef.current = false;
        let active = true;
        setRawResults([]);
        setLoadingMore(false);
        setTotalCount(0);
        setHasMore(false);
        setQueryLoading(true);
        setError(null);

        emptyClassroomRepo
            .listAvailableRooms({
                year,
                term,
                week: filters.week,
                day: filters.day,
                startPeriod: filters.startPeriod,
                endPeriod: filters.endPeriod,
                buildings: filters.buildings,
                roomIds: filters.roomIds,
                keyword: filters.keyword,
                page: 1,
                pageSize: AVAILABLE_ROOM_PAGE_SIZE,
                sortMode,
                sortDirection,
            })
            .then(result => {
                if (!active || queryRequestSeq.current !== seq) return;
                setRawResults(
                    sortRoomAvailabilityResults(
                        buildRoomAvailabilityResults(result.rows),
                        sortMode,
                        sortDirection,
                    ),
                );
                setTotalCount(result.totalCount);
                setHasMore(result.hasMore);
            })
            .catch(cause => {
                if (!active || queryRequestSeq.current !== seq) return;
                setRawResults([]);
                setTotalCount(0);
                setHasMore(false);
                setError(toMessage(cause));
            })
            .finally(() => {
                if (active && queryRequestSeq.current === seq) setQueryLoading(false);
            });

        return () => {
            active = false;
        };
    }, [
        canLoad,
        completedDays,
        debouncedFilters,
        revision,
        reloadToken,
        sortDirection,
        sortMode,
        term,
        year,
    ]);

    const setDay = useCallback(
        (day: number) => {
            if (!Number.isInteger(day) || day < 1 || day > DAYS || day === selectedDayRef.current) return;
            updateDay(day);
        },
        [updateDay],
    );

    const setBuildings = useCallback((nextBuildings: string[]) => {
        setBuildingFiltersState([...new Set(nextBuildings)]);
        setRoomIdsState([]);
    }, []);

    const setRoomIds = useCallback((nextRoomIds: number[]) => {
        setRoomIdsState([...new Set(nextRoomIds.filter(roomId => Number.isInteger(roomId) && roomId > 0))]);
    }, []);

    const setPeriodRange = useCallback((nextStartPeriod: number, nextEndPeriod: number) => {
        const left = clampPeriod(nextStartPeriod);
        const right = clampPeriod(nextEndPeriod);
        setStartPeriodState(Math.min(left, right));
        setEndPeriodState(Math.max(left, right));
    }, []);

    const toggleSortDirection = useCallback(() => {
        setSortDirection(current => (current === "asc" ? "desc" : "asc"));
    }, []);

    const reload = useCallback(() => setReloadToken(value => value + 1), []);

    const results = useMemo(
        () => sortRoomAvailabilityResults(rawResults, sortMode, sortDirection),
        [rawResults, sortDirection, sortMode],
    );
    const loadMore = useCallback(() => {
        const filters = debouncedFilters;
        if (
            !canLoad ||
            filters.week === null ||
            filters.day === null ||
            !completedDays.includes(filters.day) ||
            !hasMore ||
            queryLoading ||
            loadingMoreRef.current
        ) {
            return;
        }

        const seq = queryRequestSeq.current;
        const nextPage = pageRef.current + 1;
        loadingMoreRef.current = true;
        setLoadingMore(true);
        setError(null);

        emptyClassroomRepo
            .listAvailableRooms({
                year,
                term,
                week: filters.week,
                day: filters.day,
                startPeriod: filters.startPeriod,
                endPeriod: filters.endPeriod,
                buildings: filters.buildings,
                roomIds: filters.roomIds,
                keyword: filters.keyword,
                page: nextPage,
                pageSize: AVAILABLE_ROOM_PAGE_SIZE,
                sortMode,
                sortDirection,
                includeTotal: false,
            })
            .then(result => {
                if (queryRequestSeq.current !== seq) return;
                const pageResults = buildRoomAvailabilityResults(result.rows);
                setRawResults(current =>
                    sortRoomAvailabilityResults([...current, ...pageResults], sortMode, sortDirection),
                );
                setHasMore(result.hasMore);
                pageRef.current = nextPage;
            })
            .catch(cause => {
                if (queryRequestSeq.current !== seq) return;
                setError(toMessage(cause));
            })
            .finally(() => {
                if (queryRequestSeq.current !== seq) return;
                loadingMoreRef.current = false;
                setLoadingMore(false);
            });
    }, [
        canLoad,
        completedDays,
        debouncedFilters,
        hasMore,
        queryLoading,
        sortDirection,
        sortMode,
        term,
        year,
    ]);
    const waitingForDebounce = currentFilterKey !== debouncedFilterKey;

    return {
        snapshots,
        selectedWeek,
        selectedDay,
        completedDays,
        buildingFilters,
        roomIds,
        keyword,
        startPeriod,
        endPeriod,
        sortMode,
        sortDirection,
        results,
        totalCount,
        hasMore,
        loading: catalogLoading || daysLoading || queryLoading || waitingForDebounce,
        loadingMore,
        error,
        setDay,
        setBuildings,
        setRoomIds,
        setKeyword,
        setPeriodRange,
        setSortMode,
        toggleSortDirection,
        loadMore,
        reload,
    };
}
