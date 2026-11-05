import {useCallback, useEffect, useRef, useState} from "react";
import {teacherApi} from "@/features/teachersInfo/api";
import type {SimpleTeacherInfo} from "@/features/teachersInfo/type/info.ts";
import type {TeacherInfoDetail} from "@/features/teachersInfo/type/info";

type TeacherDetailState = {
    data: TeacherInfoDetail | null;
    loading: boolean;
    error: string | null;
};

/**
 * 查询教师详情，并让过期请求无法覆盖当前页面状态。
 * @param teacher 查询结果页传入的教师基础信息
 * @returns 详情数据、加载状态、错误信息和重试函数
 */
export function useDetail(teacher: SimpleTeacherInfo): TeacherDetailState & {retry: () => Promise<void>} {
    const [state, setState] = useState<TeacherDetailState>({
        data: null,
        loading: true,
        error: null,
    });
    const requestId = useRef(0);

    const load = useCallback(async () => {
        const id = ++requestId.current;
        setState({data: null, loading: true, error: null});

        try {
            const {data} = await teacherApi.profile(teacher.name, teacher.unit);
            if (requestId.current !== id) return;
            setState({data, loading: false, error: data ? null : "暂无教师信息"});
        } catch (error) {
            if (requestId.current !== id) return;
            const message = error instanceof Error && error.message ? error.message : "教师信息加载失败，请稍后重试";
            setState({data: null, loading: false, error: message});
        }
    }, [teacher.name, teacher.unit]);

    useEffect(() => {
        load();

        return () => {
            requestId.current += 1;
        };
    }, [load]);

    return {
        ...state,
        retry: load,
    };
}
