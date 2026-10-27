/** 楼栋与教室名之间使用 NUL，避免拼接后产生歧义。 */
export const ROOM_KEY_SEPARATOR = "\u0000";

/**
 * 教室业务键：building + "\u0000" + name。
 * 接口没有稳定的教室编号，只能以楼栋 + 教室名作为业务键。
 */
export function roomKey(building: string, name: string): string {
    return `${building}${ROOM_KEY_SEPARATOR}${name}`;
}
