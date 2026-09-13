import React from "react";
import {FlexWidget, TextWidget} from "react-native-android-widget";

import {CourseItem} from "./CourseItem";
import type {WidgetCourse, WidgetScheduleData} from "./widgetScheduleData";

interface CourseScheduleWidgetProps {
    data: WidgetScheduleData;
    theme: "light" | "dark";
    width: number;
    height: number;
}

function getDayOfWeek(offset = 0): string {
    const days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
    const date = new Date();
    date.setDate(date.getDate() + offset);
    return days[date.getDay()];
}

function getCourseDay(course: WidgetCourse): string {
    const date = new Date(`${course.date}T00:00:00`);
    return ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][date.getDay()];
}

function getEmptyMessage(state: WidgetScheduleData["state"]): string {
    if (state === "missingSchedule") return "请先在应用内同步课表";
    if (state === "missingStartDay") return "暂无当前学期开学日期";
    if (state === "error") return "课表读取失败，点击刷新";
    return "本学期已无后续课程";
}

function formatUpdatedAt(timestamp: number): string {
    const date = new Date(timestamp);
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    const hours = String(date.getHours()).padStart(2, "0");
    const minutes = String(date.getMinutes()).padStart(2, "0");
    return `${month}-${day} ${hours}:${minutes}`;
}

export function CourseScheduleWidget({data, theme, width, height}: CourseScheduleWidgetProps) {
    let displayTitle = `今天 / ${getDayOfWeek()}`;
    let courses: WidgetCourse[] = [];

    const isDark = theme === "dark";
    const compact = height < 220;
    const veryCompact = height < 145;
    const narrow = width < 260;
    const availableHeight = height - (veryCompact ? 54 : compact ? 76 : 94);
    const rowHeight = compact ? 54 : 68;
    const maxRows = Math.max(1, Math.min(8, Math.floor(availableHeight / rowHeight)));

    if (data.today.length > 0) {
        courses = data.today;
    } else if (data.tomorrow.length > 0) {
        displayTitle = `明日课程预告 / ${getDayOfWeek(1)}`;
        courses = data.tomorrow;
    } else if (data.next) {
        displayTitle = `下一节课 / ${getCourseDay(data.next)}`;
        courses = [data.next];
    }

    const coursesToDisplay = courses.slice(0, maxRows);
    const moreCoursesCount = courses.length - coursesToDisplay.length;

    return (
        <FlexWidget
            style={{
                height: "match_parent",
                width: "match_parent",
                padding: compact ? 10 : 16,
                backgroundColor: isDark ? "#2d2d2f" : "#f4f8ff",
                borderRadius: 16,
                flexDirection: "column",
            }}>
            <FlexWidget
                style={{
                    width: "match_parent",
                    flexDirection: "row",
                    justifyContent: "space-between",
                    alignItems: "center",
                    marginBottom: compact ? 4 : 8,
                }}>
                <FlexWidget style={{flex: 1}}>
                    <TextWidget
                        text={displayTitle}
                        style={{
                            fontSize: compact ? 15 : 17,
                            fontWeight: "bold",
                            fontFamily: "Inter-SemiBold",
                            color: isDark ? "#cfcfcf" : "#333333",
                        }}
                        maxLines={1}
                    />
                    {!veryCompact && (
                        <TextWidget
                            text={`更新于 ${formatUpdatedAt(data.refreshedAt)}`}
                            style={{
                                fontSize: compact ? 11 : 15,
                                fontFamily: "Inter-SemiBold",
                                color: isDark ? "#cfcfcf" : "#333333",
                            }}
                        />
                    )}
                </FlexWidget>
                <FlexWidget clickAction="REFRESH_SCHEDULE" style={{padding: 4}}>
                    <TextWidget
                        text="↻"
                        style={{
                            fontSize: compact ? 20 : 22,
                            color: isDark ? "#acacac" : "#555555",
                        }}
                    />
                </FlexWidget>
            </FlexWidget>

            {coursesToDisplay.length > 0 ? (
                <FlexWidget style={{flexDirection: "column", width: "match_parent"}}>
                    {coursesToDisplay.map((item, index) => (
                        <CourseItem
                            theme={theme}
                            key={`${item.date}-${item.index}-${index}`}
                            course={item}
                            compact={compact}
                            narrow={narrow}
                        />
                    ))}

                    {moreCoursesCount > 0 && !veryCompact && (
                        <TextWidget
                            text={`...还有 ${moreCoursesCount} 节课`}
                            style={{
                                fontSize: 12,
                                color: isDark ? "#aaaaaa" : "#888888",
                                marginTop: 6,
                            }}
                        />
                    )}
                </FlexWidget>
            ) : (
                <FlexWidget style={{flex: 1, justifyContent: "center", alignItems: "center"}}>
                    <TextWidget
                        text={getEmptyMessage(data.state)}
                        style={{
                            fontSize: compact ? 14 : 16,
                            color: isDark ? "#aaaaaa" : "#888888",
                        }}
                        maxLines={2}
                    />
                </FlexWidget>
            )}
        </FlexWidget>
    );
}
