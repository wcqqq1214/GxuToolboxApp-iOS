import {ROOM_ROW_BYTES, SLOT_ROW_BYTES} from "./constants";

const BYTE_UNITS = ["B", "KB", "MB", "GB", "TB"] as const;

/** 把字节数格式化成人类可读文本，例如 5_816_148 -> "5.5 MB"。 */
export function formatBytes(bytes: number): string {
    if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";

    let value = bytes;
    let unitIndex = 0;
    while (value >= 1024 && unitIndex < BYTE_UNITS.length - 1) {
        value /= 1024;
        unitIndex += 1;
    }

    const text = unitIndex === 0 ? String(Math.round(value)) : value.toFixed(1).replace(/\.0$/, "");
    return `${text} ${BYTE_UNITS[unitIndex]}`;
}

/**
 * 周缓存大小估算：slotCount * 38 + roomCount * 130。
 * 不落库，避免公式调整后旧行留下过期值。
 */
export function estimateSizeBytes(slotCount: number, roomCount: number): number {
    const slots = Number.isFinite(slotCount) && slotCount > 0 ? slotCount : 0;
    const rooms = Number.isFinite(roomCount) && roomCount > 0 ? roomCount : 0;
    return slots * SLOT_ROW_BYTES + rooms * ROOM_ROW_BYTES;
}

/** 缓存时间显示为 "MM-DD HH:mm"；非法/缺失值返回空串。 */
export function formatCacheTime(value: Date | number | null | undefined): string {
    if (value === null || value === undefined) return "";
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) return "";

    const pad = (part: number) => String(part).padStart(2, "0");
    return `${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
