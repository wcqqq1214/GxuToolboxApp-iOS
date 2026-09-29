import {AttendanceSystemType as AST} from "@/type/api/auth/attendanceSystem.ts";
import {store} from "@/core/store.ts";
import moment from "moment";
import {SchoolTermValue, SchoolYearValue} from "@/type/global.ts";
import {backendHttp} from "@/features/backend/api";
import {mmkv} from "@/store/mmkv.ts";
import type {AttendanceSession} from "@/core/auth/attendance/attendance.type.ts";

import type {RecordPage, Schedule} from "@gxutool/adapters/attendance";

// ─── helper：统一处理 token + headers ───

async function getAuthHeaders(): Promise<Record<string, string> | null> {
    const session = mmkv.getObject<AttendanceSession>("attendanceSession");
    if (!session?.token) return null;
    return {Authorization: "Token " + session.token};
}

async function authGet<T>(path: string, params?: Record<string, any>): Promise<T | undefined> {
    const headers = await getAuthHeaders();
    if (!headers) return;
    const res = await backendHttp.get(`/attendance${path}`, {headers, params});
    return res.data as T;
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

    async getBySchoolTerm(year: SchoolYearValue | number, term: SchoolTermValue | number) {
        const list = await calenderData.getList();
        return list.find(c => c.calendarName === `${year}-${term}`);
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
async function getPersonalDataV2(year: number, term: number): Promise<RecordPage | undefined> {
    const calendarId = 2 * year + term - 4033;

    const res = await authGet<{data: RecordPage}>("/v2/personal", {
        calendarId: calendarId,
        pageSize: 500,
        orderBy: "day DESC",
    });
    return res?.data as RecordPage;
}

async function getTableDataV2(year: number, term: number, currentWeek: number): Promise<Schedule | null> {
    const session = mmkv.getObject<AttendanceSession>("attendanceSession");
    if (!session?.userId) return null;

    const calendarId = 2 * year + term - 4033;
    const res = await authGet<{data: unknown}>("/v2/schedule", {
        calendarId: calendarId,
        currentWeek: currentWeek,
        userId: session.userId,
    });
    return res?.data as Schedule;
}

// ─── 导出 ───

export const attendanceApi = {
    getMenuData,
    calenderData,
    getPersonalData,
    getPersonalDataV2,
    getTableDataV2,
};
