import {ensureJwAuthenticated} from "@/core/auth/Jw/JwMachine.ts";
import type {ApiResponse, PageData} from "@/core/type/global.ts";
import {backendHttp} from "@/features/backend/api";
import type {SelectedCourseScope} from "@/features/selectedCourse/type";
import type {SelectedCourse} from "gxu-tool-adapters/jw";

export const selectedCourseApi = {
    /** 通过规范后端接口查询全部历史或指定学期的已选课程。 */
    async getList(scope: SelectedCourseScope): Promise<PageData<SelectedCourse>> {
        if (!(await ensureJwAuthenticated())) {
            throw new Error("教务系统未登录");
        }

        const params =
            scope.kind === "term"
                ? {
                      year: scope.year,
                      term: scope.term,
                  }
                : undefined;

        const response = await backendHttp.get<ApiResponse<PageData<SelectedCourse>>>("/jw/selected-courses", {
            params,
        });

        const page = response.data?.data;
        if (!page || !Array.isArray(page.items)) {
            throw new Error("已选课程接口返回的数据格式异常");
        }
        return page;
    },
};
