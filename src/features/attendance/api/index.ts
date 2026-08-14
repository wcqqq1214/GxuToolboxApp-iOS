import {http, urlWithParams} from "@/core/http.ts";
import {userMgr} from "@/js/mgr/user.ts";
import {AttendanceSystemType as AST} from "@/type/api/auth/attendanceSystem.ts";
import {store} from "@/core/store.ts";
import moment from "moment";
import {AttendanceCourseScheduleClass} from "@/class/auth/attendanceSystem.ts";
import {SchoolTermValue, SchoolYearValue} from "@/type/global.ts";
const BASE_URL = "https://yktuipweb.gxu.edu.cn";

// ─── helper：统一处理 token + headers ───

async function getAuthHeaders(): Promise<Record<string, string> | null> {
    const loginRes = await userMgr.attendanceSystem.getLoginRes();
    if (!loginRes?.data?.token) return null;
    return {
        "Content-Type": "application/json;charset=UTF-8",
        Authorization: "Token " + loginRes.data.token,
    };
}

async function authGet<T>(path: string, params?: Record<string, any>): Promise<T | undefined> {
    const headers = await getAuthHeaders();
    if (!headers) return;
    const url = params ? urlWithParams(`${BASE_URL}${path}`, params) : `${BASE_URL}${path}`;
    const res = await http.get<T>(url, {headers});
    return res.data;
}

async function authPost<T>(path: string, params?: Record<string, any>, body?: any): Promise<T | undefined> {
    const headers = await getAuthHeaders();
    if (!headers) return;
    const url = params ? urlWithParams(`${BASE_URL}${path}`, params) : `${BASE_URL}${path}`;
    const res = await http.post<T>(url, body, {headers});
    return res.data;
}

// ─── 数据查询 ───

async function getMenuData(): Promise<AST.ResRoot<AST.MenuData> | undefined> {
    const res = await authGet<AST.ResRoot<AST.MenuData>>("/api/account/getIndexData", {rm: "SYS004"});
    if (res?.code === 600) {
        await store.save({key: "AttendanceSystemMenuData", data: res});
    }
    return res;
}

const                                                                                                                                                                                                                                                                                                                                                                                                      calenderData = {
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
    const body = {
        page_index: 1,
        page_size: 30,
        order_by: "",
        search: {ksrq: "", jsrq: "", courseId: ""},
        ...data,
    };
    return authPost<AST.PageRes<AST.AttendanceData>>(
        "/api/personalData/getPersonalData",
        {cal: termId ?? "", rm: "SYS004"},
        body,
    );
}

async function getPersonalDataCount(
    termId?: AST.Calendar["calendarId"],
    data?: AST.SearchParam,
): Promise<AST.ResRoot<AST.AttendanceDataStatistic[]> | undefined> {
    const body = {ksrq: "", jsrq: "", courseId: "", ...data};
    return authPost<AST.ResRoot<AST.AttendanceDataStatistic[]>>(
        "/api/personalData/getPersonalDataCount",
        {cal: termId ?? "", rm: "SYS004"},
        body,
    );
}

async function getAttendanceTable(
    week: number,
    termId = 18,
): Promise<AttendanceCourseScheduleClass | undefined> {
    const loginRes = await userMgr.attendanceSystem.getLoginRes();
    if (!loginRes?.data?.token) return;
    const body = {
        currentWeek: week,
        userId: loginRes.data.userInfo.userId,
    };
    const res = await authPost<AST.ResRoot<AST.AttendanceCourseSchedule>>(
        "/api/rank/selectByStudent",
        {cal: termId, rm: "SYS004"},
        body,
    );
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
