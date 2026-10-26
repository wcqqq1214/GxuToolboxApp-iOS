import {useCallback, useEffect, useRef, useState} from "react";
import {emptyClassroomRepo} from "../repo/EmptyClassroomRepo";
import {useCacheRunnerStore} from "../stores/cacheRunnerStore";
import type {LogicalTerm, RoomRecord} from "../type";

export type UseRoomListParams = {
    year: number;
    term: LogicalTerm;
    /** 只有 sheet 打开时才加载；false 时不读库。 */
    enabled: boolean;
};

export type RoomListResult = {
    rooms: RoomRecord[];
    loading: boolean;
    error: string | null;
    reload: () => void;
};

type RoomListCache = {
    key: string;
    rooms: RoomRecord[];
};

/** 模块级内存缓存；key = year|term|revision。 */
let roomListCache: RoomListCache | null = null;

function toMessage(cause: unknown): string {
    return cause instanceof Error ? cause.message : String(cause);
}

/**
 * 作用：room picker 的按需数据源；按 (year, term, runner revision) 做内存缓存。
 * 入参：year/term；enabled 由 sheet 可见性控制。
 * 出参：rooms、loading、error、reload。
 * 修改注意：不要在页面首屏直接调用 enabled=true —— listRooms 的 DISTINCT 扫描
 * 会随已缓存周线性变慢，只在打开 sheet 时加载。
 */
export function useRoomList(params: UseRoomListParams): RoomListResult {
    const {year, term, enabled} = params;
    const revision = useCacheRunnerStore(s => s.revision);
    const cacheKey = `${year}|${term}|${revision}`;

    const [rooms, setRooms] = useState<RoomRecord[]>(() =>
        roomListCache?.key === cacheKey ? roomListCache.rooms : [],
    );
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [reloadToken, setReloadToken] = useState(0);
    const requestSeq = useRef(0);

    const canLoad = enabled && Number.isInteger(year) && year > 0 && (term === 1 || term === 2);

    useEffect(() => {
        if (!canLoad) {
            requestSeq.current += 1;
            setLoading(false);
            return;
        }

        if (roomListCache?.key === cacheKey) {
            setRooms(roomListCache.rooms);
            setError(null);
            setLoading(false);
            return;
        }

        const seq = requestSeq.current + 1;
        requestSeq.current = seq;
        let active = true;

        setLoading(true);
        setError(null);

        emptyClassroomRepo
            .listRooms(year, term)
            .then(rows => {
                if (!active || requestSeq.current !== seq) return;
                roomListCache = {key: cacheKey, rooms: rows};
                setRooms(rows);
            })
            .catch(cause => {
                if (!active || requestSeq.current !== seq) return;
                setError(toMessage(cause));
            })
            .finally(() => {
                if (!active || requestSeq.current !== seq) return;
                setLoading(false);
            });

        return () => {
            active = false;
        };
    }, [canLoad, cacheKey, year, term, reloadToken]);

    const reload = useCallback(() => {
        if (roomListCache?.key === cacheKey) roomListCache = null;
        setReloadToken(value => value + 1);
    }, [cacheKey]);

    return {rooms, loading, error, reload};
}
