import {userMgr} from "@/js/mgr/user.ts";
import {AttendanceSystemType as AST} from "@/type/api/auth/attendanceSystem.ts";
import {attendanceApi} from "@/features/attendance/api";
import {backendHttp} from "@/features/backend/api";


let captchaTicket: string | null = null;

// ─── 登录相关 ───

async function getCaptchaCode(): Promise<string> {
    const res = await backendHttp.get<{data: {image: string; ticket: string | null}}>(
        "/attendance/captcha",
        {params: {num: 666}},
    );
    const payload = res.data?.data;
    if (!payload?.image) throw new Error("获取验证码失败");
    captchaTicket = payload.ticket;
    return payload.image;
}

async function login(username: string, password: string, captchaCode: string): Promise<AST.ResRoot<AST.LoginData>> {
    const res = await backendHttp.post<{data: AST.ResRoot<AST.LoginData>}>("/attendance/login", {
        username,
        password,
        captchaCode,
        ...(captchaTicket ? {ticket: captchaTicket} : {}),
    });

    const loginRes = res.data.data;
    await userMgr.attendanceSystem.storeLoginRes(loginRes);
    if (loginRes.code === 600) {
        captchaTicket = null;
        await attendanceApi.getMenuData().catch(() => undefined);
    }
    return loginRes;
}

// ─── Token 检测 ───

async function testToken(): Promise<boolean> {
    try {
        const res = await attendanceApi.getMenuData();
        return res?.code === 600;
    } catch {
        return false;
    }
}

export const attendanceAuthApi = {
    login,
    getCaptchaImage: getCaptchaCode,
    testToken,
};
