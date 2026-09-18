import {db} from "@/core/db";
import {examInfo} from "@/core/schema";
import {and, eq} from "drizzle-orm";
import {ExamInfoRepo} from "@/features/examInfo/type";

export const examInfoRepo = {
    /**
     * 作用：按 studentId/year/term 读取本地考试信息。
     * 入参：
     * - studentId：学号，必传，多用户隔离。
     * - year：学年，空字符串表示不筛选。
     * - term：学期码 1/2，空字符串表示不筛选。
     * 出参：ExamInfoRepo[]，按 time 升序。
     */
    async getList(studentId: string, year: number | "", term: string | number | ""): Promise<ExamInfoRepo[]> {
        const conditions = [eq(examInfo.studentId, studentId)];
        if (year !== "") conditions.push(eq(examInfo.year, year as number));
        if (term !== "") conditions.push(eq(examInfo.term, Number(term)));

        const result = await db
            .select()
            .from(examInfo)
            .where(and(...conditions));

        return result.map(row => ({
            id: row.id,
            studentId: row.studentId,
            year: row.year,
            term: row.term,
            course: row.course,
            classroom: row.classroom,
            time: row.time,
            type: row.type,
            seat: row.seat,
            updatedAt: Math.floor(row.updatedAt.getTime() / 1000),
        }));
    },

    /**
     * 作用：事务替换某 studentId/year/term 下的全部考试数据。
     * 入参：
     * - studentId/year/term：定位要替换的维度。
     * - items：新数据，需已带 studentId/year/term/updatedAt。
     * 修改注意：先 delete 再 insert，保证已取消的考试不残留。
     */
    async replaceByTerm(studentId: string, year: number, term: number, items: ExamInfoRepo[]): Promise<void> {
        await db.transaction(async tx => {
            await tx
                .delete(examInfo)
                .where(and(eq(examInfo.studentId, studentId), eq(examInfo.year, year), eq(examInfo.term, term)));
            for (const item of items) {
                await tx.insert(examInfo).values({
                    id: item.id,
                    studentId: item.studentId,
                    year: item.year,
                    term: item.term,
                    course: item.course,
                    classroom: item.classroom,
                    time: item.time,
                    type: item.type,
                    seat: item.seat,
                    updatedAt: new Date(item.updatedAt * 1000),
                });
            }
        });
    },
};
