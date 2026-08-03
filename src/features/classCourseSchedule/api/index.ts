import {backendHttp} from "@/features/backend/api";
import type {ClassDetail, Major, Schedule, School} from "gxu-tool-adapters/jw";

/**
 * 班级课表相关接口，对应后端 ScheduleController（路由前缀 /jw/schedule）。
 * 后端经 TransformInterceptor 统一包装为 { code, message, data }，故取 res.data.data。
 * 参数均为 query string，与后端 @Query 一一对应。
 */

/** 过滤掉空值（"" / null / undefined），避免发出 major= 这种无意义参数。选“全部”即不传。 */
function cleanParams(obj: Record<string, string | number | undefined | null>): Record<string, string | number> {
    const out: Record<string, string | number> = {};
    for (const [k, v] of Object.entries(obj)) {
        if (v !== undefined && v !== null && v !== "") out[k] = v;
    }
    return out;
}

/**
 * 将 UI 学期码归一为后端 /jw/schedule 接口约定的逻辑学期。
 *
 * UI（SchoolTerms）使用教务系统的 xqm 码：3=秋季/上学期、12=春季/下学期、16=小学期；
 * 后端 TERM_MAP 再把逻辑学期 1/2 映射回 3/12 发给教务系统，故前端需先归一为 1/2。
 * 同时兼容已传入逻辑码（1/2）的调用方。小学期（16）后端不支持，返回 undefined。
 */
function toLogicalTerm(term: string | number): string | undefined {
    switch (String(term)) {
        case "3": // 教务系统 xqm：秋季/上学期
        case "1": // 逻辑：上学期
            return "1";
        case "12": // 教务系统 xqm：春季/下学期
        case "2": // 逻辑：下学期
            return "2";
        default:
            return undefined;
    }
}

export const classScheduleApi = {
    /** 个人课表（需登录，term 接受教务系统码 3/12 或逻辑码 1/2）。后端 parseSchedule 失败时返回 null。 */
    fetchPersonalSchedule: async (year: string, term: string): Promise<Schedule | null> => {
        const logicalTerm = toLogicalTerm(term);
        if (!logicalTerm) throw new Error(`不支持的学期参数: ${term}`);
        const res = await backendHttp.get("/jw/schedule/personal", {params: cleanParams({year, term: logicalTerm})});
        return res.data.data;
    },

    /** 学院列表（硬编码，无需登录） */
    fetchSchools: async (): Promise<School[]> => {
        const res = await backendHttp.get("/jw/schedule/schools");
        return res.data.data;
    },

    /** 专业列表（需登录） */
    fetchMajors: async (grade: string, school: string): Promise<Major[]> => {
        const res = await backendHttp.get("/jw/schedule/majors", {params: cleanParams({grade, school})});
        return res.data.data;
    },

    /** 教学班列表（school/major/grade 均可缺省，每条带完整定位参数 schoolId/majorId/grade/classId）。
     *  对应 /jw/schedule/class-schedules；选中某条后用其自带的 major/grade/classid 下钻查 class-schedule 课表，
     *  这样即使年级选“全部”也能拿到每个班级各自的 grade。 */
    fetchFullClasses: async (
        year: string,
        term: string,
        school?: string,
        major?: string,
        grade?: string,
    ): Promise<ClassDetail[]> => {
        const logicalTerm = toLogicalTerm(term);
        if (!logicalTerm) throw new Error(`不支持的学期参数: ${term}`);
        const res = await backendHttp.get("/jw/schedule/class-schedules", {
            params: cleanParams({year, term: logicalTerm, school, major, grade}),
        });
        return res.data.data;
    },

    /** 班级课表（结构化，与个人课表同构 practiceList+theoryList，需登录）。后端 parseSchedule 失败时返回 null。 */
    fetchClassSchedule: async (
        year: string,
        term: string,
        major: string,
        grade: string,
        classId: string,
    ): Promise<Schedule | null> => {
        const logicalTerm = toLogicalTerm(term);
        if (!logicalTerm) throw new Error(`不支持的学期参数: ${term}`);

        const res = await backendHttp.get("/jw/schedule/class-schedule", {
            params: cleanParams({year, term: logicalTerm, major, grade, classid: classId}),
        });
        return res.data.data;
    },
};
