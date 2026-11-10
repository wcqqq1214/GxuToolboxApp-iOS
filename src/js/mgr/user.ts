import {store} from "@/core/store.ts";
import {Account} from "@/core/auth/auth.type.ts";

export const userMgr = {
    // 教务系统相关
    jw: {
        storeAccount: (username: string, password: string) => {
            return store.save({
                key: "userAccount",
                data: {
                    username,
                    password,
                },
            });
        },
        getAccount: async () => {
            try {
                return await store.load<Account>({
                    key: "userAccount",
                });
            } catch (e) {
                console.warn(e);
                return null;
            }
        },
    },
    // 认证系统相关
    auth: {
        storeAccount: (username: string, password: string) => {
            return store.save({
                key: "userAuthAccount",
                data: {
                    username,
                    password,
                },
            });
        },
        getAccount: async () => {
            try {
                return await store.load<Account>({
                    key: "userAuthAccount",
                });
            } catch (e) {
                console.warn(e);
                return null;
            }
        },
    },
    // 考勤系统相关
    attendanceSystem: {
        storeAccount: (username: string, password: string) => {
            return store.save({
                key: "attendanceSystemAccount",
                data: {
                    username,
                    password,
                },
            });
        },
        getAccount: async () => {
            try {
                return await store.load<{username: string; password: string}>({
                    key: "attendanceSystemAccount",
                });
            } catch (e) {
                console.warn(e);
                return null;
            }
        },
    },
    //文件系统相关
    wjxt: {
        storeAccount: (username: string, password: string) => {
            return store.save({
                key: "wjxtAccount",
                data: {
                    username,
                    password,
                },
            });
        },

        getAccount: async () => {
            try {
                return await store.load<{username: string; password: string}>({
                    key: "wjxtAccount",
                });
            } catch (e) {
                console.log(e);
                return {username: "", password: ""};
            }
        },

        /** 存储 OA 登录后的 token */
        storeToken: (accessToken: string) => {
            return store.save({
                key: "wjxtToken",
                data: accessToken,
            });
        },

        /** 获取 OA 的 accessToken，过期时可用 refreshToken 换新 */
        getToken: async () => {
            try {
                return await store.load<string>({
                    key: "wjxtToken",
                });
            } catch (e) {
                console.log(e);
                return null;
            }
        },

        clearAccountAndToken: async () => {
            try {
                await store.remove({
                    key: "wjxtAccount",
                });
                await store.remove({
                    key: "wjxtToken",
                });
            } catch (e) {
                console.log(e);
                return null;
            }
        },
    },
};
