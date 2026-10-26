import {ROOM_KEY_SEPARATOR, roomKey} from "@/features/emptyClassroom/utils/roomKey.ts";

describe("roomKey", () => {
    it("使用 NUL 拼接楼栋与教室名", () => {
        expect(roomKey("西一教", "101")).toBe(`西一教${ROOM_KEY_SEPARATOR}101`);
        expect(ROOM_KEY_SEPARATOR).toBe("\u0000");
    });

    it("不同楼栋/教室组合不会撞键", () => {
        expect(roomKey("A", "BC")).not.toBe(roomKey("AB", "C"));
        expect(roomKey("A", "B")).not.toBe(roomKey("A", "B "));
    });
});
