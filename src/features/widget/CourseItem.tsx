import React from "react";
import {FlexWidget, TextWidget} from "react-native-android-widget";

import {getColorForCourse} from "./courseColor";
import type {WidgetCourse} from "./widgetScheduleData";

interface CourseItemProps {
    course: WidgetCourse;
    theme: "light" | "dark";
    compact?: boolean;
    narrow?: boolean;
}

export function CourseItem({course, theme, compact = false, narrow = false}: CourseItemProps) {
    const details = narrow
        ? [course.room, course.teacher].filter(Boolean).join(" | ")
        : [`第${course.index}节`, course.room, course.teacher].filter(Boolean).join(" | ");
    const courseColor = getColorForCourse(course.name);
    const isDark = theme === "dark";

    return (
        <FlexWidget
            style={{
                width: "match_parent",
                flexDirection: "row",
                alignItems: "center",
                marginVertical: compact ? 3 : 5,
                backgroundColor: isDark ? "#4e4e4e" : "#FFF",
                borderRadius: 12,
                padding: compact ? 6 : 8,
            }}>
            <FlexWidget
                style={{
                    width: compact ? 34 : 40,
                    flexDirection: "column",
                    alignItems: "flex-end",
                }}>
                <TextWidget
                    text={course.beginTime}
                    style={{
                        fontSize: compact ? 11 : 13,
                        color: isDark ? "#aaaaaa" : "#888888",
                    }}
                />
                <TextWidget
                    text={course.endTime}
                    style={{
                        fontSize: compact ? 11 : 13,
                        color: isDark ? "#aaaaaa" : "#888888",
                        marginTop: 2,
                    }}
                />
            </FlexWidget>

            <FlexWidget
                style={{
                    width: 3,
                    height: "match_parent",
                    backgroundColor: courseColor,
                    borderRadius: 2,
                    marginHorizontal: compact ? 7 : 12,
                    paddingVertical: 5,
                }}
            />

            <FlexWidget style={{flex: 1, flexDirection: "column"}}>
                <TextWidget
                    text={course.name}
                    style={{
                        fontSize: compact ? 14 : 16,
                        fontWeight: "bold",
                        color: isDark ? "#e4e4e4" : "#222222",
                        fontFamily: "Inter-Medium",
                    }}
                    maxLines={1}
                />
                <TextWidget
                    text={details}
                    style={{
                        fontSize: compact ? 10 : 12,
                        color: isDark ? "#aaaaaa" : "#888888",
                        marginTop: 2,
                    }}
                    maxLines={1}
                />
            </FlexWidget>
        </FlexWidget>
    );
}
