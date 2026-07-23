import axios from "axios";
import {userMgr} from "@/js/mgr/user.ts";
import {
    FileSystemApiRes,
    FileListPageResult,
    FileItem,
    SearchFileRes, LoginResult,
} from "@/type/api/fileSystem/file.ts";

/** OA 文件系统 axios 实例 */
export const oaHttp = axios.create({
    baseURL: "https://oa.gxu.edu.cn/api/gxuoa",
    headers: {
        "Content-Type": "application/json",
    },
});

oaHttp.interceptors.request.use(async config => {
    if (config.url?.includes("/auth/login")) return config;

    const token = await userMgr.wjxt.getToken();
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});

oaHttp.interceptors.response.use(
    response => response,
    async error => {
        const {config, response} = error;
        if (response?.status !== 401 || config._retry || response?.data?.code === 401) return Promise.reject(error);

        config._retry = true;

        const account = await userMgr.wjxt.getAccount();
        if (!account?.username || !account?.password) return Promise.reject(error);

        const loginRes = await axios.post<FileSystemApiRes<LoginResult>>(
            "https://oa.gxu.edu.cn/api/gxuoaAuth/gxuoa/auth/login",
            {Account: account.username, Password: account.password},
            {headers: {"Content-Type": "application/json"}},
        );
        if (loginRes.data.code !== 200) return Promise.reject(error);

        const {accessToken} = loginRes.data.result;
        await userMgr.wjxt.storeToken(accessToken);

        config.headers.Authorization = `Bearer ${accessToken}`;
        return oaHttp(config);
    },
);

export const oaApi = {
    /**
     * 登录 OA 系统，成功时缓存账密和token
     */
    login: async (username: string, password: string): Promise<boolean> => {
        try {
            const res = await axios.post<FileSystemApiRes<LoginResult>>(
                "https://oa.gxu.edu.cn/api/gxuoaAuth/gxuoa/auth/login",
                {
                    Account: username,
                    Password: password,
                },
                {headers: {"Content-Type": "application/json"}},
            );
            if (res.data.code !== 200) return false;

            const {accessToken} = res.data.result;
            await userMgr.wjxt.storeAccount(username, password);
            await userMgr.wjxt.storeToken(accessToken);
            return true;
        } catch (e) {
            console.warn("OA 登录失败:", e);
            return false;
        }
    },

    /**
     * 获取文件列表（分页），keywordType默认"title"
     */
    getFileList: async (params?: {
        page?: number;
        pageSize?: number;
        keyword?: string;
        fileTypeId?: number | null;
        selectedDepartmentId?: number | null;
        keywordType?: "title";
    }): Promise<FileSystemApiRes<FileListPageResult<FileItem>> | null> => {
        try {
            const res = await oaHttp.post<FileSystemApiRes<FileListPageResult<FileItem>>>("/wenjian/page", {
                page: params?.page ?? 1,
                pageSize: params?.pageSize ?? 50,
                keyword: params?.keyword ?? "",
                fileTypeId: params?.fileTypeId ?? null,
                selectedDepartmentId: params?.selectedDepartmentId ?? null,
                keywordType: params?.keywordType ?? "title",
            });
            return res.data;
        } catch (e) {
            console.warn("获取文件列表失败:", e);
            return null;
        }
    },

    /**
     * 获取文件详情（含正文 HTML）
     */
    getFileDetail: async (fileId: number): Promise<FileSystemApiRes<FileItem> | null> => {
        try {
            const res = await oaHttp.get<FileSystemApiRes<FileItem>>("/wenjian/detail", {
                params: {
                    id: fileId,
                    Admin: false,
                },
            });
            return res.data;
        } catch (e) {
            console.warn("获取文件详情失败:", e);
            return null;
        }
    },

    /**
     * 验证 token 是否有效
     */
    testToken: async (): Promise<boolean> => {
        const res = await oaApi.getFileList({page: 1, pageSize: 1});
        return res?.code === 200;
    },

    searchFile: async (keyword: string, keywordType?: string, page?:number): Promise<SearchFileRes> => {
        const res = await oaHttp.get("/document-search/search",{
            params: {
                _wv: "20250701-2200",
                searchType: "deptDoc",
                keyword,
                keywordType: keywordType ?? "title",
                page: page ?? 1,
                pageSize: 10
            }
        });
        return res.data;
    }
};
