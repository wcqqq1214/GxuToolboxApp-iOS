import {estimateSizeBytes, formatBytes, formatCacheTime} from "@/features/emptyClassroom/utils/format.ts";

describe("estimateSizeBytes", () => {
    it("按 slotCount*38 + roomCount*130 估算", () => {
        expect(estimateSizeBytes(0, 0)).toBe(0);
        expect(estimateSizeBytes(1, 1)).toBe(168);
        expect(estimateSizeBytes(147511, 1621)).toBe(5_816_148);
    });

    it("负数/非有限值按 0 处理", () => {
        expect(estimateSizeBytes(-1, -1)).toBe(0);
        expect(estimateSizeBytes(Number.NaN, 10)).toBe(1300);
    });
});

describe("formatBytes", () => {
    it("输出带单位的可读文本", () => {
        expect(formatBytes(0)).toBe("0 B");
        expect(formatBytes(-1)).toBe("0 B");
        expect(formatBytes(1023)).toBe("1023 B");
        expect(formatBytes(1024)).toBe("1 KB");
        expect(formatBytes(1536)).toBe("1.5 KB");
        expect(formatBytes(5_816_148)).toBe("5.5 MB");
        expect(formatBytes(11_200_000)).toBe("10.7 MB");
    });

    it("无效输入回退到 0 B", () => {
        expect(formatBytes(Number.NaN)).toBe("0 B");
        expect(formatBytes(Number.POSITIVE_INFINITY)).toBe("0 B");
    });
});

describe("formatCacheTime", () => {
    it("显示 MM-DD HH:mm", () => {
        // 使用本地时间构造函数，避免测试受时区影响
        expect(formatCacheTime(new Date(2026, 9, 26, 14, 30))).toBe("10-26 14:30");
        expect(formatCacheTime(new Date(2026, 0, 2, 9, 5).getTime())).toBe("01-02 09:05");
    });

    it("缺失或非法时间返回空串", () => {
        expect(formatCacheTime(null)).toBe("");
        expect(formatCacheTime(undefined)).toBe("");
        expect(formatCacheTime(new Date("invalid"))).toBe("");
    });
});
