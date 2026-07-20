import {getDB} from "@/core/db.ts";
import {ScoreRepo} from "@/features/examScore/type";

export const scoreRepo = {
    async upsert(scores: ScoreRepo[]): Promise<void> {
        if (!scores || scores.length === 0) return;

        const db = getDB();
        console.log("ready to upsert batch:", scores.length);

        const sql = `
            INSERT INTO exam_score (id, year, term, course_name, credit, score, teacher_name, upload_at,
                                    usual_score, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE
                SET year         = excluded.year,
                    term         = excluded.term,
                    course_name  = excluded.course_name,
                    credit       = excluded.credit,
                    score        = excluded.score,
                    teacher_name = excluded.teacher_name,
                    upload_at    = excluded.upload_at,
                    usual_score  = CASE
                                       WHEN excluded.usual_score IS NOT NULL AND excluded.usual_score != ''
                                           THEN excluded.usual_score
                                       ELSE exam_score.usual_score END,
                    updated_at   = excluded.updated_at
        `;

        const commands = scores.map(score => [
            sql,
            [
                score.id,
                score.year,
                score.term,
                score.course_name,
                score.credit,
                score.score,
                score.teacher_name,
                score.upload_at,
                score.usual_score || "",
                score.updated_at,
            ],
        ]);

        await db.executeBatch(commands as any);
        console.log("upsert batch done");
    },

    async getList(year?: number | "", term?: number | ""): Promise<ScoreRepo[]> {
        const db = getDB();

        // 将前端可能的空字符串转换为数据库认的 null，方便 SQL 短路判断
        const queryYear = year === "" ? null : (year ?? null);
        const queryTerm = term === "" ? null : (term ?? null);

        const result = await db.execute(
            `
            SELECT *
            FROM exam_score
            WHERE (? IS NULL OR year = ?)
              AND (? IS NULL OR term = ?)
            ORDER BY upload_at DESC
            `,
            [
                queryYear,
                queryYear, // 对应第一个 WHERE 条件的两个问号
                queryTerm,
                queryTerm, // 对应第二个 WHERE 条件的两个问号
            ],
        );

        return (result.rows?._array || result.rows || []) as unknown as ScoreRepo[];
    },

    async updateUsualScore(id: string, score: string): Promise<void> {
        const db = getDB();
        await db.execute(
            `
                UPDATE exam_score
                SET usual_score = ?
                WHERE id = ?`,
            [score, id],
        );
    },
};
