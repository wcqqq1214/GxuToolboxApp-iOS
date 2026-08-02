import {z} from "zod";
import {ExamSchema} from "@/features/examInfo/api/schema.ts";

const rawTeacherList = z.object({
    jgh_id: z.string(),
    jxb_id: z.string(),
    jzgmc: z.string(),
    kcmc: z.string(),
    kch_id: z.string(),
    xsdm: z.string(),
    xsmc: z.string(),
    tjztmc: z.string(),
    pjmbmcb_id:z.string().optional(),
});

export const TeacherList = rawTeacherList.transform(i => ({
    /** 教工号（安全令牌）@原 jgh_id */
    securityToken: i.jgh_id,
    /** 教学班唯一标识 @原 jxb_id */
    teachingClassId: i.jxb_id,
    /** 教师姓名 @原 jzgmc */
    teacherName: i.jzgmc,
    /** 课程名称 @原 kcmc */
    courseName: i.kcmc,
    /** 课程代码 @原 kch_id */
    courseId: i.kch_id,
    /** 课程类型编码（理论/实践）@原 xsdm */
    courseTypeCode: i.xsdm,
    /** 课程类型名称 @原 xsmc */
    courseTypeName: i.xsmc,
    /** 提交状态描述 @原 tjztmc */
    submitStatus: i.tjztmc,
    /** 模板ID @原 pjmbmcb_id */
    rubricId: i.pjmbmcb_id,
}));

export const TeacherListRes = z.object({
    currentPage: z.number(),
    totalPage: z.number(),
    totalCount: z.number(),
    items: z.array(TeacherList),
});

export type EvaTeacherList = z.infer<typeof TeacherList>

export type EvaTeacherListRes = z.infer<typeof TeacherListRes>;

