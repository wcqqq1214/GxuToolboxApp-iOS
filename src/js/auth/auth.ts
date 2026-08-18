import {http, urlWithParams} from "@/core/http.ts";
import RSAUtils from "@/js/authRSA.ts";
import cheerio from "react-native-cheerio";
import {userMgr} from "@/js/mgr/user.ts";
import axios, {AxiosResponse} from "axios";
import {EngTrainingTokenRes, EngTrainingTokenResData} from "@/type/api/infoQuery/EngTraining.ts";

export const authApi = {
    /**
     * 获取统一认证登录rsa需要的公钥
     */
    getPublicKey: async (): Promise<{
        exponent: string;
        modulus: string;
    }> => {
        const res = await http.get("https://ca.gxu.edu.cn:8443/zfca/v2/getPubKey");
        return res.data;
    },

    /**
     * 登录统一认证系统
     * @param username
     * @param password
     * @param pubKey 公钥对应的`modulus`
     * @param pubKeyLength 公钥对应的`exponent`
     * @param service 登录到对应的服务
     * @return 如果指定了服务则返回对应的 `AxiosResponse` 实例，否则返回是否登录成功
     */
    login: async (
        username: string,
        password: string,
        pubKey: string,
        pubKeyLength: string,
        service: string = "",
    ): Promise<boolean | AxiosResponse> => {
        // 获取加密后的密码
        const key = RSAUtils.getKeyPair(pubKeyLength, "", pubKey);
        const reversedPwd = password.split("").reverse().join("");
        const encryptedPwd = RSAUtils.encryptedString(key, reversedPwd);

        // 获取execution属性的值
        const html = await http.get("https://ca.gxu.edu.cn:8443/zfca/login");
        const $ = cheerio.load(html.data);
        const execution = $('#fm1 > input[name="execution"]').attr("value");

        const res = await http.post(
            urlWithParams("https://ca.gxu.edu.cn:8443/zfca/login", {
                service,
            }),
            {
                username,
                password: encryptedPwd,
                execution,
                _eventId: "submit",
            },
        );
        return service ? res : /统一身份认证-主页/.test(res.data);
    },

    /**
     * 使用存储中的账号登入服务，用于获取不同服务的cookie
     * @param serviceUrl 对应服务的url
     * @return 如果指定了服务则返回对应的 `AxiosResponse` 实例，无法获取帐密时无返回
     */
    loginService: async (serviceUrl: string): Promise<AxiosResponse | void> => {
        // 获取公钥和存储中的帐密
        const rsa = await authApi.getPublicKey();
        const account = await userMgr.auth.getAccount();
        if (!account?.password || !account?.username || !rsa) return;
        // 调用登录获取对应的cookie
        return (await authApi.login(
            account.username,
            account.password,
            rsa.modulus,
            rsa.exponent,
            serviceUrl,
        )) as AxiosResponse;
    },

    /**
     * 测试是否登录成功
     */
    async testToken(): Promise<boolean> {
        const res = await http.get("http://ca.gxu.edu.cn:81/zfim/application/home/getYyfz.zf");
        console.log(res);
        return typeof res.data === "object";
    },

    async logout(): Promise<void> {
        const res = await http.get("https://ca.gxu.edu.cn:8443/zfca/logout?service=http://ca.gxu.edu.cn:81/zfim/logout");
        console.log(res);
    },


    /**
     * 登录工程训练中心，返回请求头使用的 `Authorization` 的Token（data.token）和对应的学生码
     */
    loginEngTraining: async (): Promise<{
        studentCode: string;
        data: EngTrainingTokenResData;
    }> => {
        // 获取学生码
        const studentCodeRes = await authApi.loginService(
            "http://xlzxms.gxu.edu.cn/api/security-server/dietc/loginsso/student",
        );
        if (!studentCodeRes) return;
        const studentCode = studentCodeRes.request.responseURL.match(/(?<==).*$/)[0];
        // 请求Authorization token
        const tokenParam = {
            username: studentCode,
            code: "ssocode",
            queryParam: "queryParam",
            password: "1",
        };
        const tokenRes = await axios.post<EngTrainingTokenRes>(
            "http://xlzxms.gxu.edu.cn/api/security-server/dietc/sys/authorizing/loginsso",
            tokenParam,
        );
        return {
            studentCode,
            data: tokenRes.data.datas,
        };
    },
};
