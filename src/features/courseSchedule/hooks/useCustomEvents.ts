import {useCallback, useEffect, useRef, useState} from "react";
import {customEventRepo} from "../repo/customEventRepo";
import type {CustomEvent, CustomEventInput} from "../type/customEvent";

/** 读取和编辑当前身份的实验课，隔离账号切换和过期读取，失败时保留已有数据。 */
export function useCustomEvents(ownerKey: string | null) {
    const [state, setState] = useState({
        ownerKey,
        events: [] as CustomEvent[],
        loading: true,
        error: "",
    });
    const [saving, setSaving] = useState(false);
    const activeOwner = useRef(ownerKey);
    activeOwner.current = ownerKey;
    const request = useRef(0);
    const locked = useRef(false);
    const mounted = useRef(true);

    useEffect(() => {
        mounted.current = true;
        return () => {
            mounted.current = false;
        };
    }, []);

    const refresh = useCallback(async () => {
        const sequence = ++request.current;
        if (!ownerKey) return;
        setState(previous => ({
            ownerKey,
            events: previous.ownerKey === ownerKey ? previous.events : [],
            loading: true,
            error: "",
        }));
        try {
            const events = await customEventRepo.list(ownerKey);
            if (mounted.current && sequence === request.current && activeOwner.current === ownerKey) {
                setState({ownerKey, events, loading: false, error: ""});
            }
        } catch {
            if (mounted.current && sequence === request.current && activeOwner.current === ownerKey) {
                setState(previous => ({...previous, loading: false, error: "读取实验课失败，请重试"}));
            }
        }
    }, [ownerKey]);

    useEffect(() => {
        refresh();
        return () => {
            request.current++;
        };
    }, [refresh]);

    const mutate = useCallback(
        async (operation: () => Promise<CustomEvent | number>) => {
            if (!ownerKey || locked.current || state.ownerKey !== ownerKey || state.loading) return false;
            locked.current = true;
            setSaving(true);
            const sequence = ++request.current;
            try {
                const result = await operation();
                if (mounted.current && activeOwner.current === ownerKey) {
                    if (sequence !== request.current) {
                        await refresh();
                        return true;
                    }
                    request.current++;
                    setState(previous => {
                        const events = previous.ownerKey === ownerKey ? previous.events : [];
                        return {
                            ownerKey,
                            loading: false,
                            error: "",
                            events:
                                typeof result === "number"
                                    ? events.filter(event => event.id !== result)
                                    : [...events.filter(event => event.id !== result.id), result],
                        };
                    });
                }
                return true;
            } catch {
                if (mounted.current && activeOwner.current === ownerKey) {
                    setState(previous => ({...previous, loading: false, error: "保存实验课失败，请重试"}));
                }
                return false;
            } finally {
                locked.current = false;
                if (mounted.current) setSaving(false);
            }
        },
        [ownerKey, state.ownerKey, state.loading, refresh],
    );

    const save = useCallback(
        (input: CustomEventInput, id?: number) => mutate(() => customEventRepo.save(ownerKey!, input, id)),
        [mutate, ownerKey],
    );
    const remove = useCallback(
        (id: number) =>
            mutate(async () => {
                await customEventRepo.remove(ownerKey!, id);
                return id;
            }),
        [mutate, ownerKey],
    );

    const matchesOwner = ownerKey !== null && state.ownerKey === ownerKey;
    return {
        events: matchesOwner ? state.events : [],
        loading: !matchesOwner || state.loading,
        error: matchesOwner ? state.error : "",
        saving,
        save,
        remove,
        refresh,
    };
}
