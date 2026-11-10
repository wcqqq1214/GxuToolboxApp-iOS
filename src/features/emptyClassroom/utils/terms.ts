import type {LogicalTerm} from "../type";
import {MAX_WEEKS} from "./constants";

/**
 * 把教务系统的学期表示转成逻辑学期 1|2。
 * 兼容逻辑值 1/2 与 legacy 3/12 的字符串或数字形式；其他值直接报错。
 */
export function toLogicalTerm(value: string | number): LogicalTerm {
    const raw = typeof value === "string" ? value.trim() : value;
    if (raw === 1 || raw === "1" || raw === 3 || raw === "3") return 1;
    if (raw === 2 || raw === "2" || raw === 12 || raw === "12") return 2;
    throw new Error(`无法识别的学期：${String(value)}`);
}

/** 把逻辑学期 1|2 转成 UnTermSelector / SchoolTerms 使用的字符串 "3"|"12"。 */
export function toLegacyTerm(term: LogicalTerm): "3" | "12" {
    if (term === 1) return "3";
    if (term === 2) return "12";
    throw new Error(`无法识别的逻辑学期：${String(term)}`);
}

/** 把周次夹到 1–20；非有限值回退到第 1 周。 */
export function clampWeek(week: number): number {
    if (!Number.isFinite(week)) return 1;
    return Math.min(MAX_WEEKS, Math.max(1, Math.trunc(week)));
}
