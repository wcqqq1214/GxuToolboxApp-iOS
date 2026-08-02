import {StyleSheet} from "react-native";
import {useCourseData} from "@/hooks/useCourseData.ts";
import React, {memo, useMemo} from "react";
import {Color} from "@/shared/color.ts";
import {UnPressable} from "@/components/un-ui";
import Flex from "@/components/un-ui/Flex.tsx";
import {Badge, Text, useTheme} from "@rneui/themed";
import {Icon} from "@/components/un-ui/Icon.tsx";
import {useBlocksColor} from "@/features/courseSchedule/hooks/useBlocksColor.ts";
import {useConflictCourseStore} from "@/features/courseSchedule/stores/useConflictCourseStore.ts";
import {CourseClass} from "@/class/jw/course.ts";
import {useShallow} from "zustand/react/shallow";

interface StackCourseItemProps {
    course: CourseClass[];
    activeCourse: string;
    timeRange: [number, number];
    onPress?: (courses: CourseClass[]) => void;
}

export const StackCourseItem = memo(({course, activeCourse, timeRange, onPress}: StackCourseItemProps) => {
    const parsed = useMemo(() => course.map(c => c.transformed), [course]);
    const toKey = (c: typeof parsed[0]) => c.courseCode + "_" + c.staffId;
    const activeParsed = useMemo(
        () => parsed.find(c => toKey(c) === activeCourse) ?? parsed[0],
        [parsed, activeCourse],
    );
    const {store} = useCourseData();
    const {store: conflictStore} = useConflictCourseStore();
    const timeSpanHeight = store(s => s.theme.timeSpanHeight);
    const courseItemMargin = store(s => s.theme.courseItemMargin);
    const {theme} = useTheme();
    const {getColor} = useBlocksColor();

    const courseCodes = useMemo(() => parsed.map(c => toKey(c)).sort(), [parsed]);
    const storedActive = conflictStore(s => s.getActive(courseCodes));
    const effectiveActive = storedActive ?? activeCourse;

    const active = parsed.find(c => toKey(c) === effectiveActive) ?? parsed[0];

    const handlePress = () => {
        onPress?.(course);
    };

    const span = timeRange[1] - timeRange[0] + 1;
    const y = timeRange[0] - 1;

    const baseColor = getColor({title: active.courseName, kind: "course"}) ?? theme.colors.primary;
    const backgroundColor = Color(baseColor).setAlpha(theme.mode === "light" ? 0.3 : 0.1).rgbaString;
    const textColor = Color.mix(baseColor, theme.colors.black, 0.5).rgbaString;

    const styles = useMemo(
        () =>
            StyleSheet.create({
                container: {
                    position: "absolute",
                    width: "96%",
                    marginHorizontal: "2%",
                    borderRadius: 5,
                    backgroundColor: backgroundColor,
                    height: span * timeSpanHeight - courseItemMargin * 2,
                    top: y * timeSpanHeight + courseItemMargin,
                },
                text: {
                    textAlign: "center",
                    color: textColor,
                    fontSize: 10,
                },
                badge: {
                    backgroundColor: Color.mix(theme.colors.primary, theme.colors.background, 0.35).setAlpha(0.95)
                        .rgbaString,
                    height: 16,
                    borderWidth: 1.5,
                    borderColor: theme.colors.primary,
                },
                badgeContainer: {
                    position: "absolute",
                    top: -8,
                    right: -8,
                    zIndex: 1,
                },
            }),
        [span, y, store(useShallow(s => s.theme)), baseColor],
    );

    return (
        <UnPressable style={styles.container} onPress={handlePress}>
            {course.length > 1 && (
                <Badge
                    value={course.length}
                    status="primary"
                    textStyle={{fontSize: 11, fontWeight: "bold"}}
                    containerStyle={styles.badgeContainer}
                    badgeStyle={styles.badge}
                />
            )}
            <Flex
                direction="column"
                gap={2}
                style={{
                    padding: 4,
                    height: "100%",
                    overflow: "hidden",
                }}
                align="center">
                <Text style={[styles.text, {fontWeight: "bold"}]} numberOfLines={5}>
                    {active.isAdjusted === "1" && (
                        <Text style={{color: theme.colors.warning, fontSize: 10, fontWeight: "bold"}}>(调) </Text>
                    )}
                    {active.courseName}
                </Text>
                {!!active.venueName && (
                    <Text style={styles.text}>
                        <Icon name="map-marker" size={10} color={textColor} />
                        {"\n" + active.venueName.replace("-", "\n")}
                    </Text>
                )}
                {!!active.name && (
                    <Text style={styles.text} ellipsizeMode="tail" numberOfLines={5}>
                        <Icon name="account" style={styles.text} />
                        {"\n" + active.name}
                    </Text>
                )}
            </Flex>
        </UnPressable>
    );
});
