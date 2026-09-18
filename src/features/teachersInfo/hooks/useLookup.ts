import {useEffect, useRef, useState} from "react";
import {teacherApi} from "@/features/teachersInfo/api";
import type {SimpleTeacherInfo} from "@/features/teachersInfo/type/info.ts";

type LookupState = {
    list: SimpleTeacherInfo[];
    loading: boolean;
    error: string | null;
};

/** 查询课表中的教师名称，组件只消费已经筛选好的教师列表。 */
export function useLookup(keyword: string): LookupState {
    const [state, setState] = useState<LookupState>({list: [], loading: false, error: null});
    const requestId = useRef(0);

    useEffect(() => {
        const normalizedKeyword = keyword.trim();
        const id = ++requestId.current;

        if (!normalizedKeyword) {
            setState({list: [], loading: false, error: null});
            return () => {
                ++requestId.current;
            };
        }

        setState({list: [], loading: true, error: null});

        async function load() {
            try {
                const response = await teacherApi.search(normalizedKeyword, 1);
                if (requestId.current !== id) return;

                const list = response.data.list.filter(item => item.name.trim() === normalizedKeyword);
                setState({list, loading: false, error: null});
            } catch {
                if (requestId.current === id) {
                    setState({list: [], loading: false, error: "教师信息加载失败"});
                }
            }
        }

        load();

        return () => {
            ++requestId.current;
        };
    }, [keyword]);

    return state;
}
