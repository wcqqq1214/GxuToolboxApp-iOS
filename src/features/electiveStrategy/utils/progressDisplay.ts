import type {ProgressRequirement} from "../schema/progress.ts";

/** 只格式化后端给出的实际值和要求值，达标状态仍使用 passed */
export function formatProgressRequirement(item: ProgressRequirement): string {
    const operator = item.operator === "lte" ? "≤" : "≥";
    if (item.unit === "ratio")
        return `${Number((item.actual * 100).toFixed(1))}% / ${operator}${Number((item.required * 100).toFixed(1))}%`;
    const unit = {credits: "学分", courses: "门", modules: "个"}[item.unit];
    return `${item.actual} / ${operator}${item.required} ${unit}`;
}
