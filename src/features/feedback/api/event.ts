import {http} from "@/core/http.ts";
import {userMgr} from "@/js/mgr/user.ts";
import pkg from "../../../../package.json";

export const loginJwEvent = async () => {
    await submitEvent("login_jw_success", "login");
};

export const openAppEvent = async () => {
    await submitEvent("open_app", "app");
};

export const submitEvent = async (eventName: string, feature: string) => {
    //TODO: 获取学号和版本信息
    const account = await userMgr.jw.getAccount();
    const userId = account?.username || "0";
    const appVersion = pkg.version;

    await http.post("http://api.tool.gxutech.xyz/event", {userId, eventName, feature, appVersion});
};
