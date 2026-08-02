import {CourseClass as CourseClassModel} from "@/class/jw/course.ts";
import {z} from "zod";
import {
    PageModel,
    QueryDataModel,
    QueryDate,
    QueryDateSchema,
    QueryModel,
    ScheduleClassInfo,
    SchoolTermValue,
    strNum,
    UserModel,
} from "@/type/global.ts";

/** 课程-教师 */
export interface CourseTeacher {
    /** 教师姓名 */
    xm: string;
    /** 职称名称 */
    zcmc: string;
    /** 角色名称 */
    zfjmc: string;
    /** 政治面貌 */
    zzmm: string;
}

/** 课程-学生 */
export interface CourseStudent {
    /** 学生代码 */
    xsdm: string;
    /** 学生类型标记 */
    xslxbj: string;
    /** 专业方向名称 */
    zyfxmc: string;
}

/** 课程-班级（含课程信息、排课时间、场地等中文拼音字段） */
export interface CourseClass {
    /** 场地ID */
    cd_id: string;
    /** 场地-班号 */
    cdbh: string;
    /** 场地类别名称 */
    cdlbmc: string;
    /** 场地名称 */
    cdmc: string;
    /** 重修班级 */
    cxbj: string;
    /** 重修班级名称 */
    cxbjmc: string;
    /** 节次 */
    jc: string;
    /** 节次（其它） */
    jcor: string;
    /** 节次数 */
    jcs: string;
    /** 教工号 */
    jgh_id: string;
    /** 机构排选制度 */
    jgpxzd: string;
    /** 教学班ID */
    jxb_id: string;
    /** 教学班名称 */
    jxbmc: string;
    /** 是否调课 */
    jxbsftkbj: string;
    /** 教学班组成 */
    jxbzc: string;
    /** 课程标记 */
    kcbj: string;
    /** 课程号 */
    kch: string;
    /** 课程号ID */
    kch_id: string;
    /** 课程类别 */
    kclb: string;
    /** 课程名称 */
    kcmc: string;
    /** 课程学时组成 */
    kcxszc: string;
    /** 课程选择 */
    kcxz: string;
    /** 课程总学时 */
    kczxs: string;
    /** 考核方式名称 */
    khfsmc: string;
    /** 开课状态 */
    kkzt: string;
    /** 楼号 */
    lh: string;
    /** 旧节次 */
    oldjc: string;
    /** 旧周次 */
    oldzc: string;
    /** 排课班级 */
    pkbj: string;
    /** QQ群号 */
    qqqh: string;
    /** 授课方式名称 */
    skfsmc: string;
    /** 学分 */
    xf: string;
    /** 选课备注 */
    xkbz: string;
    /** 学年名 */
    xnm: string;
    /** 学期代码 */
    xqdm: string;
    /** 学期号 */
    xqh1: string;
    /** 学期号ID */
    xqh_id: string;
    /** 星期几 */
    xqj: string;
    /** 星期几名称 */
    xqjmc: string;
    /** 学期名 */
    xqm: string;
    /** 学期名称 */
    xqmc: string;
    /** 周次 */
    zcd: string;
    /** 周学时 */
    zhxs: string;
    /** 总学时 */
    zxs: string;
    /** 专业核心课程标记 */
    zyhxkcbj: string;
    /** 课程类型代码 */
    kklxdm: string;
    /** 考试方式名称 */
    ksfsmc: string;
    /** 年级序号 */
    njxh: number;
    /** 是否可查看课表 */
    sfkckkb: boolean;
    /** 选课人数 */
    xkrs: string;
}

/** 课程-未归类 */
export interface CourseOther {
    /** 背景颜色 */
    backgroundColor: string;
    /** 意义不明 */
    bklxdjmc: string;
    /** 排序？ */
    px: string;
    /** 意义不明 */
    rk: string;
    /** 意义不明 */
    rsdzjs: number;
    /** 意义不明 */
    sfjf: string;
    /** 意义不明 */
    sxbj: string;
    /** 意义不明 */
    zxxx: string;
    /** 意义不明 */
    zzrl: string;
}

/** 课表单项，由教师/学生/班级/查询/未归类五个维度组合 */
export interface Course extends CourseTeacher, CourseStudent, CourseClass, CourseOther, PageModel {}

/** 实践课-课程信息 */
export interface PracticalCourseInfo {
    /** 背景颜色 */
    backgroundColor: string;
    /** 教师姓名 */
    jsxm: string;
    /** 教学班组合 */
    jxbzh: string;
    /** 课程类别 */
    kclb: string;
    /** 课程名称 */
    kcmc: string;
    /** 机构排选制度 */
    jgpxzd: string;
    /** 全程实践周数 */
    qsjsz: string;
    /** 其他课程格式 */
    qtkcgs: string;
    /** 是否实践课 */
    sfsjk: string;
    /** 实践课程格式 */
    sjkcgs: string;
    /** 学分 */
    xf: string;
    /** 选课时间 */
    xksj: string;
    /** 学年名称 */
    xnmc: string;
    /** 学期名称 */
    xqmc: string;
    /** 学期名 */
    xqmmc: string;
    /** 意义不明 */
    rsdzjs: number;
}

export interface PracticalCourse
    extends
        PracticalCourseInfo,
        Pick<QueryDate, "dateDigit" | "dateDigitSeparator" | "day" | "month" | "year">,
        Pick<PageModel, "pageTotal" | "listnav" | "localeKey" | "pageable" | "rangeable" | "totalResult"> {}

export interface CourseTag {
    /** 英文文本 */
    ywxsmc?: string;
    /** 对应的符号 */
    xslxbj: string;
    /** 对应的中文文本 */
    xsmc: string;
    /** 某种序号 */
    xsdm: string;
}

/** 课表-元数据 */
export interface CourseScheduleInfo extends ScheduleClassInfo {
    /** ID */
    id: string;
    /** 行ID */
    row_id: string;
    /** 是否可查看课表 */
    sfkckkb: boolean;
    /** 课表名称 */
    tjkbmc: string;
    /** 课表制度代码 */
    tjkbzdm: string;
    /** 课表制度子代码 */
    tjkbzxsdm: string;
    /** 学年 */
    xnm: string;
    /** 学年名称 */
    xnmc: string;
    /** 学期 */
    xqm: SchoolTermValue;
    /** 学期名称 */
    xqmc: string;
    /** 学期名 */
    xqmmc: string;
    /** 意义不明 */
    rsdzjs: number;
}

export interface CourseSchedule
    extends
        CourseScheduleInfo,
        Pick<QueryDate, "date" | "dateDigit" | "dateDigitSeparator" | "day" | "month" | "year">,
        Pick<PageModel, "pageTotal"> {}

/** 物理实验课 */
export interface PhyExp {
    /** 实验课唯一ID，主键 */
    id: strNum;
    /** 周次 */
    zc: strNum;
    /** 班级名称 */
    bjmc: string;
    /** 上课日期 */
    skrq: string;
    /** 上课时间 */
    sksj: string;
    /** 人数 */
    rs: strNum;
    /** 课程名称 */
    kcmc: string;
    /** 实验名称 */
    xmmc: string;
    /** 教师名称，带有入职ID，例王潇漾(20230073) */
    zjjs: string;
    /** 教师姓名 */
    zjjsxm: string;
    /** 星期 */
    xq: strNum;
    /** 上课地点 */
    fjbh: string;
    /** 实验室名称 */
    sysmc: string;
}

/** 选课分页类型 */
export enum CourseListTypeId {
    Major = "01",
    Optional = "10",
    PE = "05",
    Special = "09",
    Other = "11",
}
export interface CourseSelectionListItem {
    /** 保留原因人数 */
    blyxrs: string;
    /** 比例占用率 */
    blzyl: string;
    /** 重修班级标识 */
    cxbj: string;
    /** 中文格式日期 */
    date: string;
    /** 数字格式日期 */
    dateDigit: string;
    /** 分隔符格式日期 */
    dateDigitSeparator: string;
    /** 日 */
    day: string;
    /** 方向班级标识 */
    fxbj: string;
    /** 机构排选制度 */
    jgpxzd: string;
    /** 教学班ID */
    jxb_id: string;
    /** 教学班名称 */
    jxbmc: string;
    /** 教学班学分 */
    jxbxf: string;
    /** 教学班总人数 */
    jxbzls: string;
    /** 课程号 */
    kch: string;
    /** 课程号ID */
    kch_id: string;
    /** 课程类型名称 */
    kclxmc: string;
    /** 课程名称 */
    kcmc: string;
    /** 课程行 */
    kcrow: string;
    /** 课程类型代码 */
    kklxdm: CourseListTypeId;
    /** 课程种类名称 */
    kzmc: string;
    /** 列表导航 */
    listnav: string;
    /** 本地化键 */
    localeKey: string;
    /** 月份 */
    month: string;
    /** 总页数 */
    pageTotal: number;
    /** 是否可分页 */
    pageable: boolean;
    /** 查询模型 */
    queryModel: QueryModel;
    /** 是否可范围选择 */
    rangeable: boolean;
    /** 任务总学时 */
    rwzxs: string;
    /** 总结果数 */
    totalResult: string;
    /** 用户模型 */
    userModel: UserModel;
    /** 学分 */
    xf: string;
    /** 选修课班级 */
    xxkbj: string;
    /** 年份 */
    year: string;
    /** 已选人数 */
    yxzrs: string;
    /** 主从跟班标识 */
    zcongbj: string;
}

// ============ Zod schemas (拼音键名 → 可读英文键名) ============

/** 课程-教师，拼音键名→英文可读 */
export const CourseTeacherSchema = z
    .object({
        xm: z.string().optional().default(""),
        zcmc: z.string().optional().default(""),
        zfjmc: z.string().optional().default(""),
        zzmm: z.string().optional().default(""),
    })
    .transform(({xm, zcmc, zfjmc, zzmm}) => ({
        /** 教师姓名 */ name: xm,
        /** 职称名称 */ title: zcmc,
        /** 角色名称 */ role: zfjmc,
        /** 政治面貌 */ politicalStatus: zzmm,
    }));
export type CourseTeacherParsed = z.infer<typeof CourseTeacherSchema>;

/** 课程-学生，拼音键名→英文可读 */
export const CourseStudentSchema = z
    .object({
        xsdm: z.string().optional().default(""),
        xslxbj: z.string().optional().default(""),
        zyfxmc: z.string().optional().default(""),
    })
    .transform(({xsdm, xslxbj, zyfxmc}) => ({
        /** 学生代码 */ studentCode: xsdm,
        /** 学生类型标记 */ studentType: xslxbj,
        /** 专业方向名称 */ majorDirection: zyfxmc,
    }));
export type CourseStudentParsed = z.infer<typeof CourseStudentSchema>;

/** 课程-班级（含课程、场地、节次周次、学期等），拼音键名→英文可读 */
export const CourseClassSchema = z
    .object({
        cd_id: z.string().optional().default(""),
        cdbh: z.string().optional().default(""),
        cdlbmc: z.string().optional().default(""),
        cdmc: z.string().optional().default(""),
        cxbj: z.string().optional().default("0"),
        cxbjmc: z.string().optional().default(" "),
        jc: z.string().optional().default("1-2节"),
        jcor: z.string().optional().default("1-2"),
        jcs: z.string().optional().default("1-2"),
        jgh_id: z.string().optional().default(""),
        jgpxzd: z.string().optional().default("1"),
        jxb_id: z.string().optional().default(""),
        jxbmc: z.string().optional().default(""),
        jxbsftkbj: z.string().optional().default("0"),
        jxbzc: z.string().optional().default(""),
        kcbj: z.string().optional().default(""),
        kch: z.string().optional().default(""),
        kch_id: z.string().optional().default(""),
        kclb: z.string().optional().default(""),
        kcmc: z.string().optional().default("课程名称"),
        kcxszc: z.string().optional().default(""),
        kcxz: z.string().optional().default(""),
        kczxs: z.coerce.string().optional().default("0"),
        khfsmc: z.string().optional().default(""),
        kkzt: z.string().optional().default("1"),
        lh: z.string().optional().default(""),
        oldjc: z.string().optional().default(""),
        oldzc: z.string().optional().default(""),
        pkbj: z.string().optional().default("1"),
        qqqh: z.string().optional().default(" "),
        skfsmc: z.string().optional().default(" "),
        xf: z.coerce.string().optional().default("0.0"),
        xkbz: z.string().optional().default(" "),
        xnm: z.string().optional().default("2025"),
        xqdm: z.string().optional().default("0"),
        xqh1: z.string().optional().default("1,"),
        xqh_id: z.string().optional().default("1"),
        xqj: z.coerce.string().optional().default("1"),
        xqjmc: z.string().optional().default("星期一"),
        xqm: z.string().optional().default("12"),
        xqmc: z.string().optional().default(""),
        zcd: z.string().optional().default("1-16周"),
        zhxs: z.coerce.string().optional().default("2"),
        zxs: z.coerce.string().optional().default("32"),
        zyhxkcbj: z.string().optional().default("否"),
        kklxdm: z.string().optional().default("01"),
        ksfsmc: z.string().optional().default(""),
        njxh: z.number().optional().default(0),
        sfkckkb: z.boolean().optional().default(true),
        xkrs: z.string().optional().default("0"),
    })
    .transform(data => ({
        /** 场地ID */ venueId: data.cd_id,
        /** 场地-班号 */ venueCode: data.cdbh,
        /** 场地类别名称 */ venueCategory: data.cdlbmc,
        /** 场地名称 */ venueName: data.cdmc,
        /** 重修班级 */ retakeClass: data.cxbj,
        /** 重修班级名称 */ retakeClassName: data.cxbjmc,
        /** 节次 */ period: data.jc,
        /** 节次（其它） */ periodOther: data.jcor,
        /** 节次数 */ periodCount: data.jcs,
        /** 教工号 */ staffId: data.jgh_id,
        /** 机构排选制度 */ orgSystem: data.jgpxzd,
        /** 教学班ID */ teachingClassId: data.jxb_id,
        /** 教学班名称 */ teachingClassName: data.jxbmc,
        /** 是否调课 */ isAdjusted: data.jxbsftkbj,
        /** 教学班组成 */ teachingClassComposition: data.jxbzc,
        /** 课程标记 */ courseFlag: data.kcbj,
        /** 课程号 */ courseCode: data.kch,
        /** 课程号ID */ courseCodeId: data.kch_id,
        /** 课程类别 */ courseCategory: data.kclb,
        /** 课程名称 */ courseName: data.kcmc,
        /** 课程学时组成 */ courseHoursComposition: data.kcxszc,
        /** 课程选择 */ courseType: data.kcxz,
        /** 课程总学时 */ courseTotalHours: data.kczxs,
        /** 考核方式名称 */ examMethod: data.khfsmc,
        /** 开课状态 */ courseStatus: data.kkzt,
        /** 楼号 */ building: data.lh,
        /** 旧节次 */ oldPeriod: data.oldjc,
        /** 旧周次 */ oldWeek: data.oldzc,
        /** 排课班级 */ scheduledClass: data.pkbj,
        /** QQ群号 */ qqGroup: data.qqqh,
        /** 授课方式名称 */ teachingMethod: data.skfsmc,
        /** 学分 */ credits: data.xf,
        /** 选课备注 */ selectionNote: data.xkbz,
        /** 学年名 */ academicYear: data.xnm,
        /** 学期代码 */ termCode: data.xqdm,
        /** 学期号 */ termNumber: data.xqh1,
        /** 学期号ID */ termId: data.xqh_id,
        /** 星期几 */ weekday: +data.xqj,
        /** 星期几名称 */ weekdayName: data.xqjmc,
        /** 学期名 */ termName: data.xqm,
        /** 学期名称 */ termNameShort: data.xqmc,
        /** 周次 */ weekRange: data.zcd,
        /** 周学时 */ weeklyHours: data.zhxs,
        /** 总学时 */ totalHours: data.zxs,
        /** 专业核心课程标记 */ isCoreCourse: data.zyhxkcbj,
        /** 课程类型代码 */ courseTypeCode: data.kklxdm,
        /** 考试方式名称 */ examMethodName: data.ksfsmc,
        /** 年级序号 */ gradeOrder: data.njxh,
        /** 是否可查看课表 */ isViewable: data.sfkckkb,
        /** 选课人数 */ enrollmentCount: data.xkrs,
    }));
export type CourseClassParsed = z.infer<typeof CourseClassSchema>;

/** 未归类字段，键名保持原样 */
export const CourseOtherSchema = z.object({
    backgroundColor: z.string().optional().default("#0000cd"),
    bklxdjmc: z.string().optional().default(" "),
    px: z.string().optional().default("1"),
    rk: z.string().optional().default("8"),
    rsdzjs: z.number().optional().default(0),
    sfjf: z.string().optional().default("0"),
    sxbj: z.string().optional().default("1"),
    zxxx: z.string().optional().default(" "),
    zzrl: z.string().optional().default("1300"),
});
export type CourseOtherParsed = z.infer<typeof CourseOtherSchema>;

/** 实践课，拼音键名→英文可读 */
export const PracticalCourseSchema = z
    .object({
        jsxm: z.string().optional().default(""),
        jxbzh: z.string().optional().default(""),
        kclb: z.string().optional().default(""),
        kcmc: z.string().optional().default("课程名称"),
        qsjsz: z.string().optional().default(""),
        qtkcgs: z.string().optional().default(""),
        sfsjk: z.string().optional().default(""),
        sjkcgs: z.string().optional().default(""),
        xf: z.coerce.string().optional().default("0.0"),
        xksj: z.string().optional().default(""),
        xnmc: z.string().optional().default(""),
        xqmc: z.string().optional().default(""),
        xqmmc: z.string().optional().default(""),
        jgpxzd: z.string().optional().default(""),
        backgroundColor: z.string().optional().default("#0000cd"),
        rsdzjs: z.number().optional().default(0),
    })
    .merge(QueryDateSchema.omit({date: true}))
    .merge(QueryDataModel.omit({queryModel: true, userModel: true}))
    .transform(data => ({
        /** 教师姓名 */ teacherName: data.jsxm,
        /** 教学班组合 */ classGroup: data.jxbzh,
        /** 课程类别 */ courseCategory: data.kclb,
        /** 课程名称 */ courseName: data.kcmc,
        /** 全程实践周数 */ fullPracticeWeeks: data.qsjsz,
        /** 其他课程格式 */ otherCourseFormat: data.qtkcgs,
        /** 是否实践课 */ isPractical: data.sfsjk,
        /** 实践课程格式 */ practicalFormat: data.sjkcgs,
        /** 学分 */ credits: data.xf,
        /** 选课时间 */ selectTime: data.xksj,
        /** 学年名称 */ academicYearName: data.xnmc,
        /** 学期名称 */ termName: data.xqmc,
        /** 学期名 */ termNameAlt: data.xqmmc,
        /** 机构排选制度 */ orgSystem: data.jgpxzd,
        /** 背景颜色 */ backgroundColor: data.backgroundColor,
        /** 意义不明 */ rsdzjs: data.rsdzjs,
        /** 数字日期 */ dateDigit: data.dateDigit,
        /** 分隔符日期 */ dateDigitSeparator: data.dateDigitSeparator,
        /** 日 */ day: data.day,
        /** 月份 */ month: data.month,
        /** 年份 */ year: data.year,
        /** 总页数 */ pageTotal: data.pageTotal,
        /** 列表导航 */ listnav: data.listnav,
        /** 本地化键 */ localeKey: data.localeKey,
        /** 是否可翻页 */ pageable: data.pageable,
        /** 可否范围内选择 */ rangeable: data.rangeable,
        /** 结果数量 */ totalResult: data.totalResult,
    }));
export type PracticalCourseParsed = z.infer<typeof PracticalCourseSchema>;

/** 课程标记，拼音键名→英文可读 */
export const CourseTagSchema = z
    .object({
        ywxsmc: z.string().optional().default(""),
        xslxbj: z.string().optional().default(""),
        xsmc: z.string().optional().default(""),
        xsdm: z.string().optional().default(""),
    })
    .transform(data => ({
        /** 英文名称 */ englishName: data.ywxsmc ?? "",
        /** 标记符号 */ marker: data.xslxbj,
        /** 名称 */ name: data.xsmc,
        /** 代码 */ code: data.xsdm,
    }));
export type CourseTagParsed = z.infer<typeof CourseTagSchema>;

/** 课表元数据，原始数据存储在 `_ori` 中，解析后的英文键名存储在 `transformed` 中 */
export const CourseScheduleSchema = z
    .object({
        qsxqj: z.string().optional().default("1"),
        xsxx: z.any().optional().default({}),
        sjfwkg: z.boolean().optional().default(true),
        xqjmcMap: z.record(z.string(), z.string()).optional().default({}),
        xskbsfxstkzt: z.string().optional().default("1"),
        rqazcList: z.array(z.any()).optional().default([]),
        kbList: z.array(z.any()).optional().default([]),
        sjkList: z.array(PracticalCourseSchema).optional().default([]),
        xsbjList: z.array(CourseTagSchema).optional().default([]),
        zckbsfxssj: z.string().optional().default("1"),
        djdzList: z.array(z.any()).optional().default([]),
        kblx: z.number().optional().default(0),
        sfxsd: z.string().optional().default("1"),
        jfckbkg: z.boolean().optional().default(true),
        xqbzxxszList: z.array(z.any()).optional().default([]),
        xkkg: z.boolean().optional().default(true),
        sxgykbbz: z.string().optional().default(""),
        jxhjkcList: z.array(z.any()).optional().default([]),
        xnxqsfkz: z.string().optional().default("false"),
    })
    .transform(data => ({
        /** 学期起止周 */ termStartWeek: data.qsxqj,
        /** 学生信息 */ studentInfo: data.xsxx,
        /** 是否教务可控 */ isAdminControlled: data.sjfwkg,
        /** 星期名称映射 */ weekdayNameMap: data.xqjmcMap,
        /** 学生课表是否显示调课状态 */ showAdjustStatus: data.xskbsfxstkzt,
        /** 日期安排列表 */ dateArrangeList: data.rqazcList,
        /** 课表课程列表 */ kbList: data.kbList.map((c: Course) => new CourseClassModel(c)),
        /** 实践课列表 */ sjkList: data.sjkList,
        /** 课程标记列表 */ courseTagList: data.xsbjList,
        /** 周次课表是否显示时间 */ showWeekTime: data.zckbsfxssj,
        /** 调课短周列表 */ adjustShortWeekList: data.djdzList,
        /** 课表类型 */ scheduleType: data.kblx,
        /** 是否显示实践课 */ showPractice: data.sfxsd,
        /** 加分课表是否可控 */ bonusControlled: data.jfckbkg,
        /** 学期备注行政设置列表 */ termNoteList: data.xqbzxxszList,
        /** 选课是否可控 */ selectionControlled: data.xkkg,
        /** 实验课表备注 */ labNote: data.sxgykbbz,
        /** 教学环节课程列表 */ teachingLinkList: data.jxhjkcList,
        /** 学年学期是否控制 */ yearTermControlled: data.xnxqsfkz,
    }));
export type CourseScheduleParsed = z.infer<typeof CourseScheduleSchema>;

/** 完整课表单项，由教师/学生/班级/未归类/查询日期/查询数据六维合成 */
export const CourseSchema = CourseTeacherSchema.and(CourseStudentSchema)
    .and(CourseClassSchema)
    .and(CourseOtherSchema)
    .and(QueryDateSchema)
    .and(QueryDataModel);
export type CourseParsed = z.infer<typeof CourseSchema>;

/** 物理实验课，拼音键名→英文可读 */
export const PhyExpSchema = z
    .object({
        id: z.string(),
        zc: z.string(),
        bjmc: z.string(),
        skrq: z.string(),
        sksj: z.string(),
        rs: z.string(),
        kcmc: z.string(),
        xmmc: z.string(),
        zjjs: z.string(),
        zjjsxm: z.string(),
        xq: z.string(),
        fjbh: z.string(),
        sysmc: z.string(),
    })
    .transform(data => ({
        /** 实验课唯一ID */ id: data.id,
        /** 周次 */ week: data.zc,
        /** 班级名称 */ className: data.bjmc,
        /** 上课日期 */ classDate: data.skrq,
        /** 上课时间 */ classTime: data.sksj,
        /** 人数 */ count: data.rs,
        /** 课程名称 */ courseName: data.kcmc,
        /** 实验名称 */ experimentName: data.xmmc,
        /** 教师名称（含入职ID） */ teacherFull: data.zjjs,
        /** 教师姓名 */ teacherName: data.zjjsxm,
        /** 星期 */ weekday: data.xq,
        /** 上课地点 */ location: data.fjbh,
        /** 实验室名称 */ labName: data.sysmc,
    }));
export type PhyExpParsed = z.infer<typeof PhyExpSchema>;
