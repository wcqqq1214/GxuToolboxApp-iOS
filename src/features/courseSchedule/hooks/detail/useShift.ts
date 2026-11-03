import {create} from "zustand/react";
import {http} from "@/core/http.ts";

type ShiftRule = [string, string];

interface ShiftStoreState {
    shiftRules: ShiftRule[];
}

interface ShiftStoreAction {}

const useShiftStore = create<ShiftStoreState & ShiftStoreAction>()(set => ({
    shiftRules: [],
}));

/** 对课表项应用调课规则，返回处理后的新数组 */


export const useShift = () => {
    async function init() {
        try {
            const {data} = await http.get(`https://file.unde.site/GxuToolApp/data.json?_=${Date.now()}`);
            if (data?.timeShift) {
                useShiftStore.setState({shiftRules: [...data.timeShift]});
            }
        } catch {
            // 加载失败，保持默认空数组
        }
    }
    return {
        store: useShiftStore,
        init,
    };
};
