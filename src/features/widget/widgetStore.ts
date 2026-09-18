import type {Schedule} from "gxu-tool-adapters/jw";

import {mmkv, mmkvStorage} from "@/store/mmkv";

export const PERSONAL_SCHEDULE_KEY = "personalSchedule";

/** 小组件只读取 App 已经保存好的个人课表，不再维护第二份缓存。 */
export function readPersonalSchedule(): Schedule | null {
    return mmkv.getObject<Schedule>(PERSONAL_SCHEDULE_KEY) ?? null;
}

/** App 更新个人课表后，通知已上屏的小组件立即重绘。 */
export function onPersonalScheduleChanged(listener: () => void) {
    return mmkvStorage.addOnValueChangedListener(changedKey => {
        if (changedKey === PERSONAL_SCHEDULE_KEY) {
            listener();
        }
    });
}
