import {z} from "zod";
import {parseWeeks} from "@/js/nextCourses.ts";

const PracticeCourseSchema = z
    .object({
        qtkcgs: z.string().optional().default("课程名称"),
        qsjsz: z.string().optional().default(""),
        jsxm: z.string().optional().default(""),
    })
    .loose();

const TheoryCourseSchema = z
    .object({
        cdbh: z.string().optional().default(""),
        cdmc: z.string().optional().default(""),
        jcs: z.string().optional().default("1-2"),
        kcmc: z.string().optional().default("课程名称"),
        zcd: z.string().optional().default("1-16周"),
        xqj: z.string().optional().default("1").transform(Number),
        xm: z.string().optional().default(""),
        qqqh: z.string().optional().default(""),
    })
    .loose();

const rawCourse = z.object({
    sjkList: z.array(PracticeCourseSchema).default([]),
    kbList: z.array(TheoryCourseSchema).default([]),
});

export const ICourse = rawCourse.transform(i => ({
    practiceList: i.sjkList.map(c => ({
        title: c.qtkcgs,
        time: c.qsjsz,
        teacher: c.jsxm,
        source: "jw",
    })),
    theoryList: i.kbList.map(c => ({
        location: c.cdbh || c.cdmc,
        index: c.jcs,
        begin: Number(c.jcs.split("-")[0]),
        end: Number(c.jcs.split("-")[1]),
        title: c.kcmc,
        week: parseWeeks(c.zcd),
        teacher: c.xm,
        day: c.xqj,
        qq: c.qqqh,
        source: "jw",
        raw: c,
    })),
}));

export type ICourse = z.infer<typeof ICourse>;
