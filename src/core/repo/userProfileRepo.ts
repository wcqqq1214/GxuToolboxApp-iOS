import {db} from "@/core/db";
import {userProfiles} from "@/core/schema";
import {eq} from "drizzle-orm";

export interface UserProfile {
    /** 学号 */
    student_id: string;
    /** 姓名 */
    name: string;
    id_card: string;
    grade: string;
    college: string;
    major: string;
    class_name: string;
    study_years: number;
    updated_at: number;
}

export const userProfileRepo = {
    async upsert(profile: UserProfile): Promise<void> {
        const data = {
            name: profile.name,
            idCard: profile.id_card,
            grade: profile.grade,
            college: profile.college,
            major: profile.major,
            className: profile.class_name,
            studyYears: profile.study_years,
            updatedAt: new Date(),
        };

        await db
            .insert(userProfiles)
            .values({studentId: profile.student_id, ...data})
            .onConflictDoUpdate({
                target: userProfiles.studentId,
                set: data,
            });
    },
    async get(student_id: string): Promise<UserProfile | null> {
        const result = await db.select().from(userProfiles).where(eq(userProfiles.studentId, student_id)).limit(1);

        if (result && result.length > 0) {
            const row = result[0];
            return {
                student_id: row.studentId,
                name: row.name || "",
                id_card: row.idCard || "",
                grade: row.grade || "",
                college: row.college || "",
                major: row.major || "",
                class_name: row.className || "",
                study_years: row.studyYears || 0,
                updated_at: row.updatedAt.getTime(),
            };
        }

        return null;
    },
};
