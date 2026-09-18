import {backendHttp} from "@/features/backend/api";
import type {ClassDetail, Major, Schedule, School} from "gxu-tool-adapters/jw";
import {ensureJwAuthenticated} from "@/core/auth/Jw/JwMachine.ts";

/**
 * 班级课表相关接口，对应后端 ScheduleController（路由前缀 /jw/schedule）。
 * 后端经 TransformInterceptor 统一包装为 { code, message, data }，故取 res.data.data。
 * 参数均为 query string，与后端 @Query 一一对应。
 * API 边界兼容旧教务码 3/12 与逻辑码 1/2，发给后端时统一转换成 1/2。
 */

/** 过滤掉空值（"" / null / undefined），避免发出 major= 这种无意义参数。选"全部"即不传。 */
function cleanParams(obj: Record<string, string | number | undefined | null>): Record<string, string | number> {
    const out: Record<string, string | number> = {};
    for (const [k, v] of Object.entries(obj)) {
        if (v !== undefined && v !== null && v !== "") out[k] = v;
    }
    return out;
}

/** UI 仍有旧教务码 3/12 的调用方；后端统一只接收逻辑学期 1/2。 */
function toLogicalTerm(term: string | number): 1 | 2 {
    if (term === 1 || term === 3 || term === "1" || term === "3") return 1;
    if (term === 2 || term === 12 || term === "2" || term === "12") return 2;
    throw new Error(`不支持的学期参数: ${term}`);
}

export const classScheduleApi = {
    /** 个人课表（需登录，term 为逻辑学期码 1/2）。后端 parseSchedule 失败时返回 null。 */
    fetchPersonalSchedule: async (year: string | number, term: string | number): Promise<Schedule | null> => {
        if (!(await ensureJwAuthenticated())) {
            return null;
        }
        const res = await backendHttp.get("/jw/schedule/personal", {
            params: cleanParams({year, term: toLogicalTerm(term)}),
        });
        return res.data.data;
    },

    /** 学院列表（硬编码，无需登录） */
    fetchSchools: async (): Promise<School[]> => {
        if (!(await ensureJwAuthenticated())) {
            return [];
        }
        const res = await backendHttp.get("/jw/schedule/schools");
        return res.data.data;
    },

    /** 专业列表（需登录） */
    fetchMajors: async (grade: string, school: string): Promise<Major[]> => {
        if (!(await ensureJwAuthenticated())) {
            return [];
        }
        const res = await backendHttp.get("/jw/schedule/majors", {params: cleanParams({grade, school})});
        return res.data.data;
    },

    /** 教学班列表（school/major/grade 均可缺省，每条带完整定位参数 schoolId/majorId/grade/classId）。
     *  对应 /jw/schedule/class-schedules；选中某条后用其自带的 major/grade/classid 下钻查 class-schedule 课表，
     *  这样即使年级选"全部"也能拿到每个班级各自的 grade。 */
    fetchFullClasses: async (
        year: string | number,
        term: string | number,
        school?: string,
        major?: string,
        grade?: string,
    ): Promise<ClassDetail[]> => {
        if (!(await ensureJwAuthenticated())) {
            return [];
        }
        const res = await backendHttp.get("/jw/schedule/class-schedules", {
            params: cleanParams({year, term: toLogicalTerm(term), school, major, grade}),
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
        if (!(await ensureJwAuthenticated())) {
            return null;
        }

        const res = await backendHttp.get("/jw/schedule/class-schedule", {
            params: cleanParams({year, term: toLogicalTerm(term), major, grade, classid: classId}),
        });
        return res.data.data;
    },
};
