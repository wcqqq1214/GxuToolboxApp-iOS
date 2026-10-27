import {useCallback, useEffect, useRef, useState} from "react";
import {emptyClassroomRepo} from "../repo/EmptyClassroomRepo";
import {useCacheRunnerStore} from "../stores/cacheRunnerStore";
import type {RoomBuildingSummary, RoomRecord} from "../type";

export type UseRoomBuildingsParams = {
    /** 只有 sheet 打开时才加载；false 时不读库。 */
    enabled: boolean;
};

export type RoomBuildingsResult = {
    buildings: RoomBuildingSummary[];
    loading: boolean;
    error: string | null;
    reload: () => void;
};

export type UseBuildingRoomsParams = {
    /** 当前楼栋；空串是合法值，表示教务未返回楼栋。 */
    building: string | null;
    enabled: boolean;
};

export type BuildingRoomsResult = {
    rooms: RoomRecord[];
    loading: boolean;
    error: string | null;
    reload: () => void;
};

export type UseRoomSearchParams = {
    query: string;
    /** undefined 搜索全部楼栋；空串只搜索“其他楼栋”。 */
    building?: string;
    enabled: boolean;
};

export type RoomSearchResult = {
    rooms: RoomRecord[];
    loading: boolean;
    error: string | null;
    reload: () => void;
};

const SEARCH_DEBOUNCE_MS = 250;

let cacheRevision = -1;
let buildingCache: RoomBuildingSummary[] | null = null;
const roomsByBuildingCache = new Map<string, RoomRecord[]>();

/** 写库后 revision 变化，下一次读取时整体失效。 */
function syncCacheRevision(revision: number): void {
    if (cacheRevision === revision) return;
    cacheRevision = revision;
    buildingCache = null;
    roomsByBuildingCache.clear();
}

function toMessage(cause: unknown): string {
    return cause instanceof Error ? cause.message : String(cause);
}

/**
 * 作用：教室选择器首层数据源，只读取楼栋与教室数。
 * 修改注意：全局教室维表是持久缓存；本 hook 只叠加按 revision 失效的内存缓存。
 */
export function useRoomBuildings(params: UseRoomBuildingsParams): RoomBuildingsResult {
    const {enabled} = params;
    const revision = useCacheRunnerStore(s => s.revision);
    syncCacheRevision(revision);

    const [buildings, setBuildings] = useState<RoomBuildingSummary[]>(() => buildingCache ?? []);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [reloadToken, setReloadToken] = useState(0);
    const requestSeq = useRef(0);

    useEffect(() => {
        syncCacheRevision(revision);
        if (!enabled) {
            requestSeq.current += 1;
            setLoading(false);
            return;
        }

        if (buildingCache) {
            setBuildings(buildingCache);
            setError(null);
            setLoading(false);
            return;
        }

        const seq = requestSeq.current + 1;
        requestSeq.current = seq;
        let active = true;

        setBuildings([]);
        setLoading(true);
        setError(null);

        emptyClassroomRepo
            .listRoomBuildings()
            .then(rows => {
                if (!active || requestSeq.current !== seq) return;
                buildingCache = rows;
                setBuildings(rows);
            })
            .catch(cause => {
                if (!active || requestSeq.current !== seq) return;
                setError(toMessage(cause));
            })
            .finally(() => {
                if (active && requestSeq.current === seq) setLoading(false);
            });

        return () => {
            active = false;
        };
    }, [enabled, revision, reloadToken]);

    const reload = useCallback(() => {
        buildingCache = null;
        setReloadToken(value => value + 1);
    }, []);

    return {buildings, loading, error, reload};
}

/**
 * 作用：用户进入某楼栋后，再按需读取该楼栋的教室。
 * 修改注意：空串楼栋必须保持为合法查询键，不能使用真值判断。
 */
export function useBuildingRooms(params: UseBuildingRoomsParams): BuildingRoomsResult {
    const {building, enabled} = params;
    const revision = useCacheRunnerStore(s => s.revision);
    syncCacheRevision(revision);

    const cacheKey = building === null ? "" : `${revision}|${building}`;
    const [rooms, setRooms] = useState<RoomRecord[]>(() =>
        building === null ? [] : (roomsByBuildingCache.get(cacheKey) ?? []),
    );
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [reloadToken, setReloadToken] = useState(0);
    const requestSeq = useRef(0);

    useEffect(() => {
        syncCacheRevision(revision);
        if (!enabled || building === null) {
            requestSeq.current += 1;
            setRooms([]);
            setLoading(false);
            setError(null);
            return;
        }

        const nextCacheKey = `${revision}|${building}`;
        const cached = roomsByBuildingCache.get(nextCacheKey);
        if (cached) {
            setRooms(cached);
            setError(null);
            setLoading(false);
            return;
        }

        const seq = requestSeq.current + 1;
        requestSeq.current = seq;
        let active = true;

        setRooms([]);
        setLoading(true);
        setError(null);

        emptyClassroomRepo
            .listRoomsByBuilding(building)
            .then(rows => {
                if (!active || requestSeq.current !== seq) return;
                roomsByBuildingCache.set(nextCacheKey, rows);
                setRooms(rows);
            })
            .catch(cause => {
                if (!active || requestSeq.current !== seq) return;
                setError(toMessage(cause));
            })
            .finally(() => {
                if (active && requestSeq.current === seq) setLoading(false);
            });

        return () => {
            active = false;
        };
    }, [building, enabled, revision, reloadToken]);

    const reload = useCallback(() => {
        if (building !== null) roomsByBuildingCache.delete(`${revision}|${building}`);
        setReloadToken(value => value + 1);
    }, [building, revision]);

    return {rooms, loading, error, reload};
}

/**
 * 作用：非空关键词下直接检索教室维表。
 * 修改注意：输入需要防抖；building 使用 undefined 与空串区分全局搜索和“其他楼栋”。
 */
export function useRoomSearch(params: UseRoomSearchParams): RoomSearchResult {
    const {query, building, enabled} = params;
    const revision = useCacheRunnerStore(s => s.revision);
    const normalizedQuery = query.trim();
    const [debouncedQuery, setDebouncedQuery] = useState("");
    const [rooms, setRooms] = useState<RoomRecord[]>([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [reloadToken, setReloadToken] = useState(0);
    const requestSeq = useRef(0);

    useEffect(() => {
        if (!enabled || !normalizedQuery) {
            setDebouncedQuery("");
            return;
        }

        const timer = setTimeout(() => setDebouncedQuery(normalizedQuery), SEARCH_DEBOUNCE_MS);
        return () => clearTimeout(timer);
    }, [enabled, normalizedQuery]);

    useEffect(() => {
        if (!enabled || !debouncedQuery) {
            requestSeq.current += 1;
            setRooms([]);
            setLoading(false);
            setError(null);
            return;
        }

        const seq = requestSeq.current + 1;
        requestSeq.current = seq;
        let active = true;

        setRooms([]);
        setLoading(true);
        setError(null);

        emptyClassroomRepo
            .searchRooms(debouncedQuery, building)
            .then(rows => {
                if (!active || requestSeq.current !== seq) return;
                setRooms(rows);
            })
            .catch(cause => {
                if (!active || requestSeq.current !== seq) return;
                setError(toMessage(cause));
            })
            .finally(() => {
                if (active && requestSeq.current === seq) setLoading(false);
            });

        return () => {
            active = false;
        };
    }, [building, debouncedQuery, enabled, reloadToken, revision]);

    const reload = useCallback(() => {
        setReloadToken(value => value + 1);
    }, []);

    const waitingForDebounce = !!normalizedQuery && normalizedQuery !== debouncedQuery;
    return {rooms, loading: loading || waitingForDebounce, error, reload};
}
