import React from "react";
import type {WidgetInfo, WidgetTaskHandlerProps} from "react-native-android-widget";

import {CourseScheduleWidget} from "./CourseScheduleWidget";
import {scheduleNextWidgetRefresh} from "./widgetRefreshScheduler";
import {getWidgetSchedule} from "./widgetScheduleData";

export const COURSE_SCHEDULE_WIDGET = "CourseScheduleWidgetProvider";

export async function renderCourseScheduleWidget(widgetInfo: Pick<WidgetInfo, "width" | "height">) {
    const data = await getWidgetSchedule();
    scheduleNextWidgetRefresh(data.nextRefreshAt);

    return {
        light: <CourseScheduleWidget data={data} theme="light" width={widgetInfo.width} height={widgetInfo.height} />,
        dark: <CourseScheduleWidget data={data} theme="dark" width={widgetInfo.width} height={widgetInfo.height} />,
    };
}

export async function widgetTaskHandler(props: WidgetTaskHandlerProps) {
    if (props.widgetInfo.widgetName !== COURSE_SCHEDULE_WIDGET || props.widgetAction === "WIDGET_DELETED") {
        return;
    }
    if (props.widgetAction === "WIDGET_CLICK" && props.clickAction !== "REFRESH_SCHEDULE") {
        return;
    }

    try {
        props.renderWidget(await renderCourseScheduleWidget(props.widgetInfo));
    } catch (error) {
        console.error("[CourseScheduleWidget] Render failed", error);
    }
}
