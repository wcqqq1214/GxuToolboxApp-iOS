import {requestWidgetUpdate} from "react-native-android-widget";

import {COURSE_SCHEDULE_WIDGET, renderCourseScheduleWidget} from "./widgetTaskHandler";
import {onPersonalScheduleChanged} from "./widgetStore";

let subscription: ReturnType<typeof onPersonalScheduleChanged> | null = null;

/** 注册一次即可：personalSchedule 写入 MMKV 后，所有已上屏实例立即刷新。 */
export function registerCourseScheduleWidgetUpdates() {
    if (subscription) return;

    subscription = onPersonalScheduleChanged(() => {
        requestWidgetUpdate({
            widgetName: COURSE_SCHEDULE_WIDGET,
            renderWidget: renderCourseScheduleWidget,
        }).catch(error => {
            console.error("[CourseScheduleWidget] Immediate update failed", error);
        });
    });
}
