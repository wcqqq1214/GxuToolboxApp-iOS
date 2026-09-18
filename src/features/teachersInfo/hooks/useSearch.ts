import {useCallback, useEffect, useRef, useState} from "react";
import {teacherApi} from "@/features/teachersInfo/api";
import type {SimpleTeacherInfo} from "@/features/teachersInfo/type/info.ts";

type SearchState = {
    keyword: string;
    list: SimpleTeacherInfo[];
    page: number;
    pages: number;
    total: number;
    status: "idle" | "search" | "more";
    searchError: string | null;
    loadMoreError: string | null;
};

const EMPTY: SearchState = {
    keyword: "",
    list: [],
    page: 1,
    pages: 0,
    total: 0,
    status: "idle",
    searchError: null,
    loadMoreError: null,
};

function errorMessage(error: unknown, fallback: string): string {
    return error instanceof Error && error.message ? error.message : fallback;
}

export function useSearch() {
    const [keyword, setKeyword] = useState("");
    const [state, setState] = useState<SearchState>(EMPTY);
    const requestId = useRef(0);

    const search = useCallback(async (value: string) => {
        const normalized = value.trim();
        if (!normalized) return;

        const id = ++requestId.current;
        setState({...EMPTY, keyword: normalized, status: "search"});

        try {
            const {list, pages, total} = (await teacherApi.search(normalized, 1)).data;
            if (requestId.current !== id) return;
            setState({...EMPTY, keyword: normalized, list, pages, total});
        } catch (error) {
            if (requestId.current !== id) return;
            setState(s => ({...s, status: "idle", searchError: errorMessage(error, "查询失败，请稍后重试")}));
        }
    }, []);

    const fetchMore = useCallback(async () => {
        const {keyword: active, page, pages, status} = state;
        if (!active || status !== "idle" || page >= pages) return;

        const nextPage = page + 1;
        const id = ++requestId.current;
        setState(s => ({...s, status: "more", loadMoreError: null}));

        try {
            const {list, pages: newPages, total} = (await teacherApi.search(active, nextPage)).data;
            if (requestId.current !== id) return;
            setState(s => ({...s, list: [...s.list, ...list], page: nextPage, pages: newPages, total, status: "idle"}));
        } catch (error) {
            if (requestId.current !== id) return;
            setState(s => ({...s, status: "idle", loadMoreError: errorMessage(error, "加载更多失败，请重试")}));
        }
    }, [state]);

    const loadMore = useCallback(() => {
        if (!state.loadMoreError) fetchMore();
    }, [state.loadMoreError, fetchMore]);

    const retrySearch = useCallback(() => search(state.keyword), [search, state.keyword]);

    const reset = useCallback(() => {
        ++requestId.current;
        setState(EMPTY);
    }, []);

    useEffect(() => {
        return () => {
            ++requestId.current;
        };
    }, []);

    return {
        teacherInfoList: state.list,
        keyword,
        setKeyword,
        totalResults: state.total,
        hasMore: state.page < state.pages,
        isSearching: state.keyword !== "",
        isSearchingNow: state.status === "search",
        isLoadingMore: state.status === "more",
        searchErrorMessage: state.searchError,
        loadMoreErrorMessage: state.loadMoreError,
        search,
        retrySearch,
        loadMore,
        retryLoadMore: fetchMore,
        reset,
    };
}
