import {useEffect, useState} from "react";
import {COOLDOWN_MS} from "../utils/constants";

export type CooldownState = {
    /** 距离下次可开始缓存还剩多少毫秒；不在冷却中时为 0。 */
    remainingMs: number;
    /** 是否仍在冷却窗口内。 */
    blocked: boolean;
};

type CooldownSnapshot = {
    /** 已夹到当前时刻的起始时间；0 表示没有有效冷却。 */
    base: number;
    /** 本次计算的当前时间。 */
    now: number;
};

function clampStartedAt(value: number, now: number): number {
    if (!Number.isFinite(value) || value <= 0) return 0;
    // 未来时间（时钟回拨/损坏数据）从当前时刻起算一个窗口，避免永久锁死。
    return Math.min(value, now);
}

function computeSnapshot(lastStartedAt: number): CooldownSnapshot {
    const now = Date.now();
    return {base: clampStartedAt(lastStartedAt, now), now};
}

function remainingOf(snapshot: CooldownSnapshot): number {
    if (snapshot.base <= 0) return 0;
    const elapsed = snapshot.now - snapshot.base;
    if (elapsed <= 0) return COOLDOWN_MS;
    return Math.max(0, Math.min(COOLDOWN_MS, COOLDOWN_MS - elapsed));
}

/**
 * 作用：根据最近一次缓存开始时间计算冷却剩余时间，并且只在冷却中每秒 tick。
 * 入参：lastStartedAt（毫秒时间戳；0/非法值表示无冷却）。
 * 出参：{remainingMs, blocked}。
 * 修改注意：未来时间戳会夹到当前时刻，最多只锁一个 COOLDOWN_MS 窗口，不会永久禁用按钮。
 */
export function useCooldown(lastStartedAt: number): CooldownState {
    const [snapshot, setSnapshot] = useState<CooldownSnapshot>(() => computeSnapshot(lastStartedAt));

    useEffect(() => {
        setSnapshot(computeSnapshot(lastStartedAt));
    }, [lastStartedAt]);

    const remainingMs = remainingOf(snapshot);
    const blocked = remainingMs > 0;

    useEffect(() => {
        if (!blocked) return;

        const timer = setInterval(() => {
            setSnapshot(previous => ({...previous, now: Date.now()}));
        }, 1000);
        return () => clearInterval(timer);
    }, [blocked, snapshot.base]);

    return {remainingMs, blocked};
}
