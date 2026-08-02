import {z} from "zod";

/** 递归地将类型的所有属性变为可选 */
export type DeepPartial<T> = T extends object
    ? { [P in keyof T]?: DeepPartial<T[P]> }
    : T;

export const SchoolYears = [
    ["2028", "2028-2029"],
    ["2027", "2027-2028"],
    ["2026", "2026-2027"],
    ["2025", "2025-2026"],
    ["2024", "2024-2025"],
    ["2023", "2023-2024"],
    ["2022", "2022-2023"],
    ["2021", "2021-2022"],
    ["2020", "2020-2021"],
    ["2019", "2019-2020"],
    ["2018", "2018-2019"],
    ["2017", "2017-2018"],
    ["2016", "2016-2017"],
    ["2015", "2015-2016"],
    ["2014", "2014-2015"],
    ["2013", "2013-2014"],
    ["2012", "2012-2013"],
    ["2011", "2011-2012"],
    ["2010", "2010-2011"],
    ["2009", "2009-2010"],
    ["2008", "2008-2009"],
    ["2007", "2007-2008"],
    ["2006", "2006-2007"],
    ["2005", "2005-2006"],
] as const;
export type SchoolYearsType = typeof SchoolYears;
export type SchoolYearValue = typeof SchoolYears[number][0] | number;
export type SchoolYearLabel = typeof SchoolYears[number][1];

/** `number` 的字符串类型，可直接转换 */
export type strNum = string;
/** `boolean` 的字符串类型，可直接转换  */
export type strBool = string;
/** `boolean` 的数字类型，`0` 为 false，`1` 为 true  */
export type numBool = 0 | 1;

export const SchoolTerms = [
    ["3", "秋季学期"],
    ["12", "春季学期"],
    ["16", "小学期"],
]as const;
export type SchoolTermsType = typeof SchoolTerms;
export type SchoolTermValue = typeof SchoolTerms[number][0] | number;
export type SchoolTermLabel = typeof SchoolTerms[number][1];

export const Schools = [
    ["10100", "党委办公室、校长办公室（校务督查办公室、法治与法务办公室）"],
    ["10300", "党委组织部（中共广西大学委员会党校）"],
    ["10400", "党委宣传部"],
    ["10500", "党委学生工作部、学生工作处、武装部（就业指导中心）"],
    ["10700", "校团委"],
    ["10800", "校工会"],
    ["20100", "党委教师工作部、人力资源处"],
    ["20200", "发展规划处"],
    ["20300", "教务处（教师教学发展中心）"],
    ["20400", "研究生院"],
    ["20700", "国有资产与实验室管理处（招标与采购管理中心）"],
    ["20800", "财务处"],
    ["20900", "招生就业指导中心"],
    ["21000", "离退休工作处"],
    ["21200", "保卫处（治安综合治理委员会办公室）"],
    ["21300", "校友工作办公室"],
    ["21500", "国际合作与交流处（港澳台事务办公室、留学生管理服务中心）"],
    ["21600", "科研院"],
    ["04070F72F38A65E1E063020410AC9F71", "教育教学质量监控与评价中心（高等教育研究所、教学督导团）"],
    ["25000", "后勤管理处"],
    ["25100", "后勤基建处"],
    ["30100", "机械工程学院"],
    ["30200", "电气工程学院"],
    ["30300", "土木建筑工程学院"],
    ["30400", "化学化工学院"],
    ["30500", "轻工与食品工程学院"],
    ["30700", "计算机与电子信息学院"],
    ["31000", "海洋学院"],
    ["31100", "数学与信息科学学院"],
    ["31200", "物理科学与工程技术学院"],
    ["31300", "生命科学与技术学院"],
    ["31600", "马克思主义学院"],
    ["31700", "艺术学院"],
    ["32000", "新闻与传播学院"],
    ["32100", "文学院"],
    ["32200", "公共管理学院"],
    ["32300", "商学院"],
    ["32400", "法学院"],
    ["32500", "外国语学院"],
    ["33100", "农学院"],
    ["33400", "动物科学技术学院"],
    ["33600", "林学院"],
    ["33700", "医学院"],
    ["33900", "资源环境与材料学院"],
    ["34000", "中国－东盟经济学院／经济学院／中国－东盟金融合作学院"],
    ["34100", "体育学院"],
    ["34200", "工商管理学院"],
    ["34300", "经济学院／中国—东盟金融合作学院"],
    ["713531B3C2D93E41E053020410AC9D64", "国际学院"],
    ["40100", "图书馆"],
    ["40200", "信息网络中心（网络安全与信息化办公室）"],
    ["40400", "图书馆（档案馆）"],
    ["41600", "中国－东盟研究院／广西创新发展研究院"],
    ["60100", "资产经营有限公司"],
    ["60200", "农牧产业发展研究院"],
] as const;
export type SchoolValue = typeof Schools[number][0];
export type SchoolLabel = typeof Schools[number][1];

export interface QueryModel {
    /**  */
    currentPage: number;
    /**  */
    currentResult: number;
    /**  */
    entityOrField: boolean;
    /**  */
    limit: number;
    /**  */
    offset: number;
    /**  */
    pageNo: number;
    /**  */
    pageSize: number;
    /**  */
    showCount: number;
    /**  */
    sorts: any[];
    /**  */
    totalCount: number;
    /**  */
    totalPage: number;
    /**  */
    totalResult: number;
}

export interface UserModel {
    /**  */
    monitor: boolean;
    /**  */
    roleCount: number;
    /**  */
    roleKeys: string;
    /**  */
    roleValues: string;
    /**  */
    status: number;
    /**  */
    usable: boolean;
}

/** 教务系统查询类请求接口返回的基本数据类型，看上去是数据库分页查询时的通用参数 */
export interface QueryResRoot<T> {
    /** 结果列表 */
    items: T[];
    /** 当前页 */
    currentPage: number;
    /** 当前结果？ */
    currentResult: number;
    /** 是否是实体还是字段？ */
    entityOrField: boolean;
    /** 每页显示数量 */
    limit: number;
    /** 分页偏移量 */
    offset: number;
    /** 页码？ */
    pageNo: number;
    /** 每页显示数量 */
    pageSize: number;
    /** 显示数据总数（？）可能用于遍历 */
    showCount: number;
    /** 排序字段？ */
    sortName: string;
    /** 排序方式，asc/desc */
    sortOrder: string;
    /** 排序字段列表？ */
    sorts: any[];
    /** 符合查询条件的总数，包括没有返回的数据，用于前端分页组件计算总页数等等 */
    totalCount: number;
    /** 符合查询条件的总页数，用于前端分页组件显示 */
    totalPage: number;
    /** 符合查询条件的总结果数，用于前端分页组件显示？ */
    totalResult: number;
}

/** 查询日期 */
export interface QueryDate {
    /** 中文查询日期 */
    date: string;
    /** 数字查询日期 */
    dateDigit: string;
    /** 分隔符数字查询日期 */
    dateDigitSeparator: string;
    /** （年月）日 */
    day: string;
    /** 月份 */
    month: string;
    /** 年份 */
    year: string;
}

export const QueryDateSchema = z.object({
    date: z.string().optional().default(""),
    dateDigit: z.string().optional().default(""),
    dateDigitSeparator: z.string().optional().default(""),
    day: z.string().optional().default(""),
    month: z.string().optional().default(""),
    year: z.string().optional().default(""),
});

/** 教务分页查询时通用属性，目前仅在不带有返回根的接口存在 */
export interface PageModel extends QueryDate {
    /** 总页数 */
    pageTotal: number;
    /** 查询模型 */
    queryModel: QueryModel,
    /** 用户模型 */
    userModel: UserModel,
    /** 列表导航 */
    listnav: string;
    /** 本地化键 */
    localeKey: string;
    /** 是否可翻页 */
    pageable: boolean;
    /** 可否范围内选择 */
    rangeable: boolean;
    /** 结果数量，意义不明，总是为 `"0"`（目前） */
    totalResult: string;
}

export const QueryDataModel = z.object({
    pageTotal: z.number().optional().default(0),
    queryModel: z.any().optional().default({}),
    userModel: z.any().optional().default({}),
    listnav: z.string().optional().default("false"),
    localeKey: z.string().optional().default("zh_CN"),
    pageable: z.boolean().optional().default(true),
    rangeable: z.boolean().optional().default(true),
    totalResult: z.string().optional().default("0"),
});

/** 课表-班级基础信息 */
export interface ScheduleClassInfo {
    /** 班级名称 */
    bjmc: string;
    /** 机构代码 */
    jgdm: SchoolValue;
    /** 年级代码 */
    njdm: string;
    /** 选课人数 */
    xkrs: string;
    /** 学生学院序号 */
    xsxyxh: number;
}
