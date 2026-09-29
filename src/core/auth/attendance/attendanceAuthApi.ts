import {attendanceApi} from "@/features/attendance/api";
import {backendHttp} from "@/features/backend/api";
import {mmkv} from "@/store/mmkv.ts";
import type {AttendanceLoginInput, AttendanceSession} from "@/core/auth/attendance/attendance.type.ts";

// ─── 登录相关 ───

async function getCaptcha(): Promise<{challengeToken: string | null; imageUrl: string; text: string | null}> {
    const {data} = await backendHttp.get<{
        data: {imageUrl: string; challengeToken: string | null; text: string | null};
    }>("/attendance/v2/captcha");

    return data.data;
}

async function login(input: AttendanceLoginInput): Promise<AttendanceSession> {
    const {data} = await backendHttp.post<{code: number; data: AttendanceSession}>("/attendance/v2/login", input);

    return data.data;
}

// ─── Token 检测 ───

async function testToken(): Promise<boolean> {
    const session = mmkv.getObject<AttendanceSession>("attendanceSession");
    if (!session?.userId) return false;

    const res = await attendanceApi.getMenuData();
    return res?.code === 200;
}

export const attendanceAuthApi = {
    login,
    getCaptcha,
    testToken,
};
