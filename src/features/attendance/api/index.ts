import {userMgr} from "@/js/mgr/user.ts";
import {AttendanceSystemType as AST} from "@/type/api/auth/attendanceSystem.ts";
import {store} from "@/core/store.ts";
import moment from "moment";
import {AttendanceCourseScheduleClass} from "@/class/auth/attendanceSystem.ts";
import {SchoolTermValue, SchoolYearValue} from "@/type/global.ts";
import {backendHttp} from "@/features/backend/api";

// ─── helper：统一处理 token + headers ───

async function getAuthHeaders(): Promise<Record<string, string> | null> {
    const loginRes = await userMgr.attendanceSystem.getLoginRes();
    if (!loginRes?.data?.token) return null;
    return {Authorization: "Token " + loginRes.data.token};
}

async function authGet<T>(path: string, params?: Record<string, any>): Promise<T | undefined> {
    const headers = await getAuthHeaders();
    if (!headers) return;
    const res = await backendHttp.get(`/attendance${path}`, {headers, params});
    return res.data.data as T;
}

// ─── 数据查询 ───

async function getMenuData(): Promise<AST.ResRoot<AST.MenuData> | undefined> {
    const res = await authGet<AST.ResRoot<AST.MenuData>>("/index-data");
    if (res?.code === 600) {
        await store.save({key: "AttendanceSystemMenuData", data: res});
    }
    return res;
}

const calenderData = {
    async getList() {
        const storeData = await store
            .load<AST.ResRoot<AST.MenuData>>({key: "AttendanceSystemMenuData"})
            .catch(() => null);
        if (!storeData) {
            const res = await getMenuData();
            return res?.code === 600 ? res.data.calendarList : [];
        }
        return storeData.data.calendarList;
    },

    async get(date: moment.MomentInput) {
        const dateM = moment(date);
        const list = await calenderData.getList();
        return list.find(c => dateM.isBetween(c.firstWeekBegin, c.lastWeekEnd, "d", "[]"));
    },

    async getByTermId(termId: number) {
        const list = await calenderData.getList();
        return list.find(c => c.calendarId === termId);
    },

    async getBySchoolTerm(year: SchoolYearValue | number, term: SchoolTermValue | number) {
        const list = await calenderData.getList();
        return list.find(c => c.calendarName === `${year}-${term}`);
    },

    async getCurrent() {
        return (await calenderData.getList()).find(c => c.isCurrent);
    },
};

async function getPersonalData(
    termId?: AST.Calendar["calendarId"],
    data?: Partial<AST.PageQueryParam>,
): Promise<AST.PageRes<AST.AttendanceData> | undefined> {
    return authGet<AST.PageRes<AST.AttendanceData>>("/personal-data", {
        cal: termId,
        page_index: data?.page_index ?? 1,
        page_size: data?.page_size ?? 30,
        order_by: data?.order_by,
        ksrq: data?.search?.ksrq,
        jsrq: data?.search?.jsrq,
        courseId: data?.search?.courseId,
    });
}

async function getPersonalDataCount(
    termId?: AST.Calendar["calendarId"],
    data?: AST.SearchParam,
): Promise<AST.ResRoot<AST.AttendanceDataStatistic[]> | undefined> {
    return authGet<AST.ResRoot<AST.AttendanceDataStatistic[]>>("/personal-data-count", {
        cal: termId,
        ksrq: data?.ksrq,
        jsrq: data?.jsrq,
        courseId: data?.courseId,
    });
}

async function getAttendanceTable(
    week: number,
    termId?: number,
): Promise<AttendanceCourseScheduleClass | undefined> {
    const loginRes = await userMgr.attendanceSystem.getLoginRes();
    if (!loginRes?.data?.token) return;
    const cal = termId ?? (await calenderData.getCurrent())?.calendarId;
    const res = await authGet<AST.ResRoot<AST.AttendanceCourseSchedule>>("/schedule", {
        cal,
        currentWeek: week,
        userId: loginRes.data.userInfo.userId,
    });
    if (!res) return;
    return new AttendanceCourseScheduleClass(res.data);
}

// ─── 导出 ───

export const attendanceApi = {
    getAuthHeaders,
    getMenuData,
    calenderData,
    getPersonalData,
    getPersonalDataCount,
    getAttendanceTable,
};
