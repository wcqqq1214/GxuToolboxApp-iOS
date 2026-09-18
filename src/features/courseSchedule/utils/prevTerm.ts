/**
 * 作用：推算给定学期的"上一个学期"（逻辑学期码 1/2）。
 * 入参：
 * - year：学年，如 2025 表示 2025-2026 学年。
 * - term：逻辑学期码，1=上学期(秋) / 2=下学期(春)。
 * 出参：
 * - 返回上一学期的 { year, term }。学年内顺序为 1(秋) -> 2(春)，春季之后进入下一学年的秋季。
 * 修改注意：
 * - 纯函数，不读 DB，只依据编码递推关系。适用于 ChooseTerm 假期默认回退等只需 year/term 的场景。
 * - 不要用于需要开学日期的场景（那应查 termStartDay 表）。
 */
export function prevTerm(year: number, term: number): {year: number; term: number} {
    if (term === 2) return {year, term: 1}; // 春(2) -> 同年秋(1)
    return {year: year - 1, term: 2}; // 秋(1) -> 上一年春(2)
}
