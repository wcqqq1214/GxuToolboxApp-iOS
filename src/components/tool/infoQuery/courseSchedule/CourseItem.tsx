import React, {useMemo} from "react";
import {StyleSheet, ViewStyle} from "react-native";
import {Color} from "@/shared/color.ts";
import {UnPressable} from "@/components/un-ui";
import Flex from "@/components/un-ui/Flex.tsx";
import {Text, useTheme} from "@rneui/themed";
import {Icon} from "@/components/un-ui/Icon.tsx";
import {CourseClass} from "@/class/jw/course.ts";
import {AttendanceSystemType as AST} from "@/type/api/auth/attendanceSystem.ts";
import {useCourseData} from "@/hooks/useCourseData.ts";
import {AttendanceStateIcon} from "@/features/courseSchedule/components/AttendanceStateIcon.tsx";

interface Props {
    style?: ViewStyle;
    course: CourseClass;
    attendanceState?: AST.AttendanceState;
    onCoursePress?: (course: CourseClass) => void;
}

export function CourseItem(props: Props) {
    const {store, courseScheduleStyle} = useCourseData();
    const timeSpanHeight = store(s => s.theme.timeSpanHeight);
    const weekdayHeight = store(s => s.theme.weekdayHeight);
    const courseItemMargin = store(s => s.theme.courseItemMargin);
    const courseInfoVisible = store(s => s.courseInfoVisible);
    const {theme} = useTheme();
    const {course} = props;
    const span = parseInt(course._ori.sectionRange.split("-")[1], 10) - parseInt(course._ori.sectionRange.split("-")[0], 10) + 1;
    const y = +course._ori.sectionRange.split("-")[0] - 1;
    const itemStyle = useMemo(() => {
        return StyleSheet.create({
            course: {
                height: span * timeSpanHeight - courseItemMargin * 2,
                position: "absolute",
                backgroundColor: Color(theme.colors.primary).setAlpha(
                    theme.mode === "light" ? 0.3 : 0.1,
                ).rgbaString,
                top:
                    weekdayHeight +
                    y * timeSpanHeight +
                    courseItemMargin,
            },
            text: {
                textAlign: "center",
                color: Color.mix(theme.colors.primary, theme.colors.black, 0.5).rgbaString,
            },
        });
    }, [
        courseItemMargin,
        timeSpanHeight,
        weekdayHeight,
        span,
        theme.colors.grey4,
        theme.mode,
        y,
    ]);
    return (
        // 课程元素
        <UnPressable
            onPress={function(e) {
                props.onCoursePress?.(course);
            }}
            style={[props.style, itemStyle.course, courseScheduleStyle.courseItem]}>
            <Flex direction="column" gap={5}>
                {courseInfoVisible.name && (
                    <Text style={[itemStyle.text, {fontWeight: 700}]}>
                        {props.attendanceState && (
                            <AttendanceStateIcon
                                defaultColor={itemStyle.text.color}
                                state={props.attendanceState ?? AST.AttendanceState.NotStarted}
                            />
                        )}
                        {course._ori.courseName}
                    </Text>
                )}
                {courseInfoVisible.position && (
                    <Text style={itemStyle.text}>
                        <Icon name="map-marker" style={itemStyle.text} />
                        {"\n" + course._ori.venueName.replace("-", "\n")}
                    </Text>
                )}
                {courseInfoVisible.teacher && (
                    <Text style={itemStyle.text} ellipsizeMode="tail" numberOfLines={5}>
                        <Icon name="account" style={itemStyle.text} />
                        {"\n" + course._ori.teacher}
                    </Text>
                )}
            </Flex>
        </UnPressable>
    );
}
