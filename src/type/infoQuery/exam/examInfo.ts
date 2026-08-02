import {z} from "zod";

/** 考试-学生信息 */
export interface ExamStudent {
    /** 学号ID，实际上就是学号 */
    xh_id: string;
    /** 学号 */
    xh: string;
    /** 姓名 */
    xm: string;
    /** 性别 */
    xb: string;
    /** 班级 */
    bj: string;
    /** 年级（名称） */
    njmc: string;
    /** 专业（名称） */
    zymc: string;
    /** 学院（名称） */
    jgmc: string;
    /** 培养层次 */
    pycc: string;
    /** 教学班名称 */
    jxbmc: string;
    /** 教学班组成 */
    jxbzc: string;
    /** 重修班级 */
    cxbj: string;
    /** 是否重修标记 */
    zxbj: string;
}

/** 考试-课程与考试信息 */
export interface ExamCourse {
    /** 考试名称 */
    ksmc: string;
    /** 考试时间 */
    kssj: string;
    /** 课程号 */
    kch: string;
    /** 课程名称 */
    kcmc: string;
    /** 考察方式 */
    khfs: string;
    /** 学分 */
    xf: string;
    /** 开课学院 */
    kkxy: string;
    /** 教师信息，前面的数字疑似入职年份和序号 */
    jsxx: string;
    /** 上课时间 */
    sksj: string;
    /** 教学地点 */
    jxdd: string;
    /** 试卷编号 */
    sjbh: string;
}

/** 考试-场地信息 */
export interface ExamVenue {
    /** 场地编号，不带楼的名称，例`综合511` */
    cdbh: string;
    /** 场地名称，带楼的名称，例`西综合511` */
    cdmc: string;
    /** 场地校庆名称 */
    cdxqmc: string;
    /** 场地简称 */
    cdjc: string;
    /** 考场座位号 */
    zwh: string;
}

/** 考试-查询与学期信息 */
export interface ExamQuery {
    /** 学期，具体值对应查看`global.ts` */
    xqm: string;
    /** 学期名称，学期组件显示的值 */
    xqmmc: string;
    /** 学年名称，选择组件显示的学年名称 */
    xnmc: string;
    /** 学年值 */
    xnm: string;
    /** 校区名称 */
    xqmc: string;
    /** 查询结果数 */
    totalresult: number;
    /** 行id，值似乎就是在表格中的行号 */
    row_id: number;
}

/** 完整考试信息，由学生/课程/场地/查询四维组合 */
export interface ExamInfo extends ExamStudent, ExamCourse, ExamVenue, ExamQuery {}

// ============ Zod schemas (拼音键名 → 可读英文键名) ============

/** 考试-学生信息，拼音键名→英文可读 */
export const ExamStudentSchema = z
    .object({
        xh_id: z.string(),
        xh: z.string(),
        xm: z.string(),
        xb: z.string(),
        bj: z.string(),
        njmc: z.string(),
        zymc: z.string(),
        jgmc: z.string(),
        pycc: z.string(),
        jxbmc: z.string(),
        jxbzc: z.string(),
        cxbj: z.string().optional(),
        zxbj: z.string().optional(),
    })
    .transform(data => ({
        /** 学号ID */ studentIdAlt: data.xh_id,
        /** 学号 */ studentId: data.xh,
        /** 姓名 */ name: data.xm,
        /** 性别 */ gender: data.xb,
        /** 班级 */ className: data.bj,
        /** 年级名称 */ gradeName: data.njmc,
        /** 专业名称 */ majorName: data.zymc,
        /** 学院名称 */ collegeName: data.jgmc,
        /** 培养层次 */ educationLevel: data.pycc,
        /** 教学班名称 */ teachingClassName: data.jxbmc,
        /** 教学班组成 */ teachingClassComposition: data.jxbzc,
        /** 重修班级 */ retakeClass: data.cxbj,
        /** 是否重修标记 */ retakeFlag: data.zxbj,
    }));
export type ExamStudentParsed = z.infer<typeof ExamStudentSchema>;

/** 考试-课程与考试信息，拼音键名→英文可读 */
export const ExamCourseSchema = z
    .object({
        ksmc: z.string(),
        kssj: z.string(),
        kch: z.string(),
        kcmc: z.string(),
        khfs: z.string(),
        xf: z.coerce.string(),
        kkxy: z.string(),
        jsxx: z.string(),
        sksj: z.string(),
        jxdd: z.string(),
        sjbh: z.string(),
    })
    .transform(data => ({
        /** 考试名称 */ examName: data.ksmc,
        /** 考试时间 */ examTime: data.kssj,
        /** 课程号 */ courseCode: data.kch,
        /** 课程名称 */ courseName: data.kcmc,
        /** 考察方式 */ examMethod: data.khfs,
        /** 学分 */ credits: data.xf,
        /** 开课学院 */ openCollege: data.kkxy,
        /** 教师信息 */ teacherInfo: data.jsxx,
        /** 上课时间 */ classTime: data.sksj,
        /** 教学地点 */ teachingLocation: data.jxdd,
        /** 试卷编号 */ paperId: data.sjbh,
    }));
export type ExamCourseParsed = z.infer<typeof ExamCourseSchema>;

/** 考试-场地信息，拼音键名→英文可读 */
export const ExamVenueSchema = z
    .object({
        cdbh: z.string(),
        cdmc: z.string(),
        cdxqmc: z.string(),
        cdjc: z.string(),
        zwh: z.string().optional(),
    })
    .transform(data => ({
        /** 场地编号 */ venueCode: data.cdbh,
        /** 场地名称 */ venueName: data.cdmc,
        /** 场地校庆名称 */ venueAnniversaryName: data.cdxqmc,
        /** 场地简称 */ venueShortName: data.cdjc,
        /** 考场座位号 */ seat: data.zwh,
    }));
export type ExamVenueParsed = z.infer<typeof ExamVenueSchema>;

/** 考试-查询与学期信息，拼音键名→英文可读 */
export const ExamQuerySchema = z
    .object({
        xqm: z.string(),
        xqmmc: z.string(),
        xnmc: z.string(),
        xnm: z.string(),
        xqmc: z.string(),
        totalresult: z.number(),
        row_id: z.number(),
    })
    .transform(data => ({
        /** 学期 */ term: data.xqm,
        /** 学期名称 */ termName: data.xqmmc,
        /** 学年名称 */ academicYear: data.xnmc,
        /** 学年值 */ academicYearCode: data.xnm,
        /** 校区名称 */ campus: data.xqmc,
        /** 查询结果数 */ totalResult: data.totalresult,
        /** 行id */ rowId: data.row_id,
    }));
export type ExamQueryParsed = z.infer<typeof ExamQuerySchema>;

/** 完整考试信息，由学生/课程/场地/查询四维合成 */
export const ExamInfoSchema = ExamStudentSchema.and(ExamCourseSchema)
    .and(ExamVenueSchema)
    .and(ExamQuerySchema);
export type ExamInfoParsed = z.infer<typeof ExamInfoSchema>;

// 考试名称数据接口
export interface ExamName {
    //
    KSXS: string;
    //
    PKSJSFYXYXSSKCT: string;
    // 可能是考试ID，用在查询详情的请求参数
    KSMCDMB_ID: string;
    // 考试名称
    KSMC: string;
    //
    SFKCFPKC: string;
    //
    SFBKBJ: string;
}
