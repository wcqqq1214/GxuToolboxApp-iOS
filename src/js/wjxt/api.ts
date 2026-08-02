import axios from "axios";
import cheerio from "react-native-cheerio";
import iconv from "iconv-lite";
import {Buffer} from "buffer";

export interface PendingFile {
    content: string;
    id: string;
}

export const wjxtHttp = axios.create({
    baseURL: "https://wjxt.gxu.edu.cn/",
    headers: {
        "Content-Type": "application/x-www-form-urlencoded",
    },
    withCredentials: true,
});

//处理编码字符串
function htmlParser(data: ArrayBuffer): string {
    return iconv.decode(Buffer.from(data), "gb2312");
}

export const wjxt = {
    /**
     * 登录，初始密码身份证前四位+后四位
     * */
    login: async (username: string, password: string) => {
        const res = await wjxtHttp.post("", {
            __VIEWSTATE: "/wEPDwUKMTY5ODE4NTcwM2RkIBnlIHU+BoqNJr+gDM0LFVpP7SfKuRBHRBLFK+Xqy3o=",
            __VIEWSTATEGENERATOR: "C2EE9ABB",
            __SCROLLPOSITIONX: "0",
            __SCROLLPOSITIONY: "0",
            userIdCard: username,
            userPwd: password,
            loginsubmit: "%B5%C7+%C2%BC",
            myteip: "172.30.135.20--2",
        });
        const response = await wjxtHttp.post("Wjxt_UI/qstwj.aspx", {}, {responseType: "arraybuffer"});

        const htmlString = htmlParser(response.data);
        return !htmlString.includes("alert");
    },

    testCookie: async () => {
        const response = await wjxtHttp.post(
            "Wjxt_UI/qstwj.aspx",
            {},
            {
                responseType: "arraybuffer",
            },
        );
        const htmlString = htmlParser(response.data);
        return !htmlString.includes("alert");
    },

    /**
     * 未读文件信息
     */
    getPendingFiles: async (): Promise<PendingFile[]> => {
        const response = await wjxtHttp.post("Wjxt_UI/qstwj.aspx", {}, {responseType: "arraybuffer"});
        const parser = cheerio.load(htmlParser(response.data));

        const spans = parser("span")
            .map((_, el) => parser(el).text().trim())
            .get()
            .filter((item: string) => item.length > 0);

        const links = parser("span a")
            .map((_, el) => {
                const href = parser(el).attr("href") ?? "";
                const match = href.match(/id=(\d+)/);
                return match ? match[1] : "";
            })
            .get();
        const res: PendingFile[] = [];
        for (let i = 0; i < spans.length; i += 3) {
            const content = spans.slice(i, i + 3).join("-");
            const id = links[Math.floor(i / 3)] ?? "";
            res.push({content, id});
        }
        return res;
    },
};
