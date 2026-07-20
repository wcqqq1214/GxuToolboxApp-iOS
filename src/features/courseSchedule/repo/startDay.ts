import {backendHttp} from "@/features/backend/api";
import {getDB} from "@/core/db.ts";

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
    const db = getDB();

    const commands: [string, any[]][] = [];

    // 清理标记
    commands.push(["UPDATE term_start_day SET is_current = 0", []]);

    // 插入数据
    for (const term of terms) {
        commands.push([
            `INSERT OR REPLACE INTO term_start_day (year, term, day, week, is_current)
             VALUES (?, ?, ?, ?, ?)`,
            [term.year, term.term, term.day, term.week, term.is_current ? 1 : 0],
        ]);
    }

    await db.executeBatch(commands);
    memoryStartDay = null;
}

export async function getCurrentStartDay(): Promise<TermStartDay | null> {
    if (memoryStartDay) return memoryStartDay;

    const db = getDB();
    const result = await db.execute("SELECT * FROM term_start_day WHERE is_current = 1 LIMIT 1");

    if (result.rows && result.rows.length > 0) {
        return result.rows[0] as unknown as TermStartDay;
    }
    return null;
}

// 从内存中获取
export function getSyncStartDay(): TermStartDay | null {
    return memoryStartDay;
}
