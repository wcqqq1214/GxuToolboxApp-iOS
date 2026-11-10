import {clampWeek, toLegacyTerm, toLogicalTerm} from "@/features/emptyClassroom/utils/terms.ts";

describe("toLogicalTerm", () => {
    it("把 legacy 3/12 的字符串或数字转成 1/2", () => {
        expect(toLogicalTerm("3")).toBe(1);
        expect(toLogicalTerm(3)).toBe(1);
        expect(toLogicalTerm("12")).toBe(2);
        expect(toLogicalTerm(12)).toBe(2);
    });

    it("逻辑学期 1/2 幂等", () => {
        expect(toLogicalTerm(1)).toBe(1);
        expect(toLogicalTerm("1")).toBe(1);
        expect(toLogicalTerm(2)).toBe(2);
        expect(toLogicalTerm("2")).toBe(2);
    });

    it("忽略字符串首尾空白", () => {
        expect(toLogicalTerm(" 3 ")).toBe(1);
        expect(toLogicalTerm(" 12 ")).toBe(2);
    });

    it("拒绝无法识别的学期", () => {
        expect(() => toLogicalTerm("16")).toThrow("无法识别的学期");
        expect(() => toLogicalTerm(16)).toThrow("无法识别的学期");
        expect(() => toLogicalTerm("")).toThrow("无法识别的学期");
    });
});

describe("toLegacyTerm", () => {
    it("返回 SchoolTerms 使用的字符串形式", () => {
        expect(toLegacyTerm(1)).toBe("3");
        expect(toLegacyTerm(2)).toBe("12");
        expect(typeof toLegacyTerm(1)).toBe("string");
        expect(typeof toLegacyTerm(2)).toBe("string");
    });

    it("拒绝非法逻辑学期", () => {
        expect(() => toLegacyTerm(3 as never)).toThrow("无法识别的逻辑学期");
    });
});

describe("clampWeek", () => {
    it("把周次夹到 1–20", () => {
        expect(clampWeek(0)).toBe(1);
        expect(clampWeek(-3)).toBe(1);
        expect(clampWeek(1)).toBe(1);
        expect(clampWeek(12)).toBe(12);
        expect(clampWeek(20)).toBe(20);
        expect(clampWeek(21)).toBe(20);
        expect(clampWeek(100)).toBe(20);
    });

    it("小数截断为非负整数周", () => {
        expect(clampWeek(3.9)).toBe(3);
    });

    it("非有限值回退到第 1 周", () => {
        expect(clampWeek(Number.NaN)).toBe(1);
        expect(clampWeek(Number.POSITIVE_INFINITY)).toBe(1);
    });
});
