export type AcademicTerm = 1 | 2;

/** 已选课程的查询范围：全部历史，或一个明确的学期。 */
export type SelectedCourseScope =
    | {kind: "all"}
    | {
          kind: "term";
          year: number;
          term: AcademicTerm;
      };

export function isAcademicTerm(value: number): value is AcademicTerm {
    return value === 1 || value === 2;
}
