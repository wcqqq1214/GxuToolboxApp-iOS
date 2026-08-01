import {backendHttp} from "@/features/backend/api";
import {db} from "@/core/db";
import {eq} from "drizzle-orm";
import {termStartDay} from "@/core/schema";

interface TermStartDay {
    year: number;
    term: number;
    day: string;
    week: number;
    is_current: boolean;
}

let memoryStartDay: TermStartDay | null = null;

export async function fetchStartDay(): Promise<TermStartDay[]> {
    const res = await backendHttp.get("/jw/profile/startDay");
    return res.data.data;
}

export async function saveToDB(terms: TermStartDay[]) {
    // 清理当前标记
    await db.update(termStartDay).set({isCurrent: false});

    // 插入或替换新数据
    for (const term of terms) {
        await db
            .insert(termStartDay)
            .values({
                year: term.year,
                term: term.term,
                day: new Date(term.day), // 转换为 Date 以适应 timestamp mode
                week: term.week,
                isCurrent: term.is_current,
            })
            .onConflictDoUpdate({
                target: [termStartDay.year, termStartDay.term],
                set: {
                    day: new Date(term.day),
                    week: term.week,
                    isCurrent: term.is_current,
                },
            });
    }

    memoryStartDay = null;
}

export async function getCurrentStartDay(): Promise<TermStartDay | null> {
    if (memoryStartDay) return memoryStartDay;

    const result = await db.select().from(termStartDay).where(eq(termStartDay.isCurrent, true)).limit(1);

    if (result && result.length > 0) {
        const row = result[0];
        // 转换回旧的接口格式以保证上层业务兼容性
        const mapped: TermStartDay = {
            year: row.year,
            term: row.term,
            day: row.day.toISOString(),
            week: row.week,
            is_current: row.isCurrent,
        };
        memoryStartDay = mapped;
        return mapped;
    }
    return null;
}

// 从内存中获取
export function getSyncStartDay(): TermStartDay | null {
    return memoryStartDay;
}
