import {http} from "@/core/http.ts";
import axios from "axios";
import {SchoolTerms} from "@/type/global.ts";
import CookieManager from "@preeternal/react-native-cookie-manager";

const JW_COOKIE_URL = "https://jwxt2018.gxu.edu.cn/jwglxt";
const BACKEND_COOKIE_URL = "https://api.tool.gxutech.xyz";

export const JwAuthClient = {
    async login(username: string, password: string): Promise<boolean> {
        await CookieManager.clearAll();

        const res = await axios.post(
            BACKEND_COOKIE_URL + "/jw/login",
            {username, password},
            {
                headers: {"Content-Type": "application/json"},
                withCredentials: true,
                timeout: 10000,
            },
        );

        const header = readHeader(res.headers["set-cookie"]);

        const session = pick(header, "JSESSIONID");
        const route = pick(header, "route");

        if (!session || !route) {
            throw new Error("missing jw cookies");
        }

        await CookieManager.set(JW_COOKIE_URL, {
            name: "JSESSIONID",
            value: session,
        });

        await CookieManager.set(JW_COOKIE_URL, {
            name: "route",
            value: route,
        });
        await CookieManager.set(BACKEND_COOKIE_URL, {
            name: "JSESSIONID",
            value: session,
        });

        await CookieManager.set(BACKEND_COOKIE_URL, {
            name: "route",
            value: route,
        });

        const saved = await CookieManager.get(JW_COOKIE_URL);

        return Boolean(saved.JSESSIONID?.value && saved.route?.value);
    },

    async testTokenRaw(): Promise<boolean> {
        const res = await http.post("/kbcx/xskbcx_cxXsgrkb.html", {
            xnm: "2021",
            xqm: SchoolTerms[0][0],
        });
        return typeof res.data === "object";
    },
};

function readHeader(value: unknown): string {
    if (Array.isArray(value)) return value.join("; ");
    if (typeof value === "string") return value;
    return "";
}

function pick(header: string, name: string): string | null {
    const pattern = new RegExp(`(?:^|[;,]\\s*)${name}=([^;,]+)`);
    return header.match(pattern)?.[1] ?? null;
}
