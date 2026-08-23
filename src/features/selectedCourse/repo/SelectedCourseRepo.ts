import {db} from "@/core/db";
import {selectedCourses} from "@/core/schema";
import type {SelectedCourseScope} from "@/features/selectedCourse/type";
import {isAcademicTerm} from "@/features/selectedCourse/type";
import {and, asc, desc, eq} from "drizzle-orm";
import type {SelectedCourse} from "gxu-tool-adapters/jw";

const INSERT_BATCH_SIZE = 50;

function assertPersistable(course: SelectedCourse): void {
    if (!course.classId.trim()) throw new Error("已选课程缺少教学班标识");
    if (!course.courseId.trim()) throw new Error("已选课程缺少课程标识");
    if (!Number.isInteger(course.year)) throw new Error(`已选课程学年无效：${course.year}`);
    if (!isAcademicTerm(course.term)) throw new Error(`已选课程学期无效：${course.term}`);
    if (!Number.isFinite(course.credit)) throw new Error(`已选课程学分无效：${course.credit}`);
}

function prepareRows(studentId: string, items: SelectedCourse[], updatedAt: Date) {
    const rows = new Map<string, typeof selectedCourses.$inferInsert>();

    for (const course of items) {
        assertPersistable(course);
        const row: typeof selectedCourses.$inferInsert = {
            studentId,
            year: course.year,
            term: course.term,
            classId: course.classId,
            courseId: course.courseId,
            courseName: course.courseName,
            type: course.type,
            selectionType: course.selectionType,
            classification: course.classification,
            belongTo: course.belongTo,
            system: course.system,
            teacher: course.teacher,
            teacherId: course.teacherId,
            credit: course.credit,
            updatedAt,
        };
        rows.set(`${course.year}:${course.term}:${course.classId}`, row);
    }

    return [...rows.values()];
}

async function insertInBatches(
    tx: Parameters<Parameters<typeof db.transaction>[0]>[0],
    rows: (typeof selectedCourses.$inferInsert)[],
): Promise<void> {
    for (let index = 0; index < rows.length; index += INSERT_BATCH_SIZE) {
        await tx.insert(selectedCourses).values(rows.slice(index, index + INSERT_BATCH_SIZE));
    }
}

export const selectedCourseRepo = {
    /** 只读取当前账号的数据，可按明确学期进一步筛选。 */
    async getList(studentId: string, scope: SelectedCourseScope): Promise<SelectedCourse[]> {
        const condition =
            scope.kind === "all"
                ? eq(selectedCourses.studentId, studentId)
                : and(
                      eq(selectedCourses.studentId, studentId),
                      eq(selectedCourses.year, scope.year),
                      eq(selectedCourses.term, scope.term),
                  );

        const rows = await db
            .select()
            .from(selectedCourses)
            .where(condition)
            .orderBy(desc(selectedCourses.year), desc(selectedCourses.term), asc(selectedCourses.courseName));

        return rows.map(({studentId: _studentId, updatedAt: _updatedAt, ...course}) => course);
    },

    /** 全量刷新：只替换当前账号的全部历史记录，不触碰其他账号。 */
    async replaceAll(studentId: string, items: SelectedCourse[]): Promise<void> {
        const rows = prepareRows(studentId, items, new Date());
        await db.transaction(async tx => {
            await tx.delete(selectedCourses).where(eq(selectedCourses.studentId, studentId));
            await insertInBatches(tx, rows);
        });
    },

    /** 学期刷新：只替换当前账号、当前学年学期的记录。 */
    async replaceByTerm(studentId: string, year: number, term: 1 | 2, items: SelectedCourse[]): Promise<void> {
        for (const course of items) {
            if (course.year !== year || course.term !== term) {
                throw new Error(`已选课程返回范围不一致：请求 ${year}/${term}，实际 ${course.year}/${course.term}`);
            }
        }

        const rows = prepareRows(studentId, items, new Date());
        await db.transaction(async tx => {
            await tx
                .delete(selectedCourses)
                .where(
                    and(
                        eq(selectedCourses.studentId, studentId),
                        eq(selectedCourses.year, year),
                        eq(selectedCourses.term, term),
                    ),
                );
            await insertInBatches(tx, rows);
        });
    },
};
