import {db} from "@/core/db";
import {examScore} from "@/core/schema";
import {and, desc, eq} from "drizzle-orm";
import {ScoreRepo} from "@/features/examScore/type";

export const scoreRepo = {
    async upsert(scores: ScoreRepo[]): Promise<void> {
        if (!scores || scores.length === 0) return;

        console.log("ready to upsert batch:", scores.length);

        for (const score of scores) {
            const existing = await db.select().from(examScore).where(eq(examScore.id, score.id)).limit(1);

            const data = {
                year: score.year,
                term: score.term,
                courseName: score.course_name,
                credit: score.credit,
                score: score.score,
                teacherName: score.teacher_name,
                uploadAt: score.upload_at,
                usualScore: score.usual_score || "",
                updatedAt: new Date(score.updated_at * 1000),
            };

            if (existing && existing.length > 0) {
                await db.update(examScore).set(data).where(eq(examScore.id, score.id));
            } else {
                await db.insert(examScore).values({id: score.id, ...data});
            }
        }

        console.log("upsert batch done");
    },

    async getList(year?: number | "", term?: number | ""): Promise<ScoreRepo[]> {
        const queryYear = year === "" ? null : (year ?? null);
        const queryTerm = term === "" ? null : (term ?? null);

        // 构建动态条件
        const conditions = [];
        if (queryYear !== null) conditions.push(eq(examScore.year, queryYear));
        if (queryTerm !== null) conditions.push(eq(examScore.term, queryTerm));

        let query = db.select().from(examScore);
        if (conditions.length > 0) {
            query = query.where(and(...conditions)) as any;
        }

        const result = await query.orderBy(desc(examScore.uploadAt));

        // 转换回旧的下划线格式返回
        return result.map(row => ({
            id: row.id,
            year: row.year,
            term: row.term,
            course_name: row.courseName,
            credit: row.credit,
            score: row.score,
            teacher_name: row.teacherName,
            upload_at: row.uploadAt,
            usual_score: row.usualScore,
            updated_at: Math.floor(row.updatedAt.getTime() / 1000),
        }));
    },

    async updateUsualScore(id: string, score: string): Promise<void> {
        await db.update(examScore).set({usualScore: score}).where(eq(examScore.id, id));
    },
};
