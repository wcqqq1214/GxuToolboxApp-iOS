import {z} from "zod";

const moduleSchema = z.enum(["lead", "entrepreneurship", "art", "asean", "ethnic", "ocean"]);
const statusSchema = z.enum(["passed", "failed", "pending", "voided", "review"]);
const credits = z.number().finite().nonnegative();
const moduleStats = z.object({credits, courseCount: z.number().int().nonnegative()});
const attemptSchema = z.object({
    year: z.number(),
    term: z.number(),
    classId: z.string(),
    credit: credits.nullable(),
    score: z.number().finite().nullable(),
    status: statusSchema,
    matchedBy: z.enum(["classId", "courseId"]).nullable(),
    locations: z.array(z.string()),
    teachers: z.array(z.string()),
    modules: z.array(moduleSchema),
    online: z.boolean(),
});

/** 校选课聚合接口契约，仅校验传输结构，不在客户端推导学分或达标结果 */
export const electiveProgressSchema = z.object({
    studentId: z.string().min(1),
    grade: z.number().int(),
    ruleId: z.string(),
    ruleVersion: z.string(),
    ruleName: z.string(),
    computedAt: z.string().refine(value => Number.isFinite(Date.parse(value))),
    complete: z.boolean(),
    stats: z.object({
        totalCredits: credits,
        offlineCredits: credits,
        modules: z.object({
            lead: moduleStats,
            entrepreneurship: moduleStats,
            art: moduleStats,
            asean: moduleStats,
            ethnic: moduleStats,
            ocean: moduleStats,
        }),
    }),
    requirements: z.array(
        z.object({
            key: z.string(),
            label: z.string(),
            actual: z.number().finite(),
            required: z.number().finite(),
            operator: z.enum(["gte", "lte"]),
            unit: z.enum(["credits", "courses", "modules", "ratio"]),
            passed: z.boolean().nullable(),
        }),
    ),
    remainingRequired: z.array(z.string()),
    courses: z.array(
        z.object({
            courseId: z.string(),
            courseName: z.string(),
            classIds: z.array(z.string()),
            locations: z.array(z.string()),
            teachers: z.array(z.string()),
            modules: z.array(moduleSchema),
            online: z.boolean().nullable(),
            credit: credits.nullable(),
            score: z.number().finite().nullable(),
            status: statusSchema,
            counted: z.boolean(),
            countedCredits: credits,
            excludedReason: z.string().nullable(),
            attempts: z.array(attemptSchema),
        }),
    ),
    issues: z.array(z.object({code: z.string(), courseId: z.string(), classId: z.string(), message: z.string()})),
    isQualified: z.boolean().nullable(),
});

export type ElectiveProgress = z.infer<typeof electiveProgressSchema>;
export type ProgressRequirement = ElectiveProgress["requirements"][number];
