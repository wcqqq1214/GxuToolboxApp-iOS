import React from "react";
import {ScrollView} from "react-native";
import {UnPressable} from "@/components/un-ui";
import {Text, useTheme} from "@rneui/themed";
import {Color} from "@/shared/color.ts";
import {CourseClass} from "@/class/jw/course.ts";
import {useConflictCourseStore} from "@/features/courseSchedule/stores/useConflictCourseStore.ts";

interface ConflictCourseListProps {
    courses: CourseClass[];
    activeCourseCode: string;
    onSelect: (course: CourseClass) => void;
    onPressActiveCourse: (course: CourseClass) => void;
}

export function ConflictCourseList({
    courses,
    activeCourseCode,
    onSelect,
    onPressActiveCourse,
}: ConflictCourseListProps) {
    const {theme} = useTheme();

    return (
        <>
            <Text h4 style={{marginBottom: 12}}>
                冲突课程
            </Text>
            <ScrollView style={{maxHeight: 300}}>
                {courses.map(c => {
                    const t = c._ori;
                    const isActive = t.courseName + "_" + t.teacher === activeCourseCode;
                    return (
                        <UnPressable
                            key={t.courseName + "_" + t.teacher}
                            onPress={function () {
                                return isActive ? onPressActiveCourse(c) : onSelect(c);
                            }}
                            style={{
                                paddingVertical: 12,
                                paddingHorizontal: 8,
                                borderLeftWidth: isActive ? 3 : 0,
                                borderLeftColor: theme.colors.primary,
                                backgroundColor: isActive
                                    ? Color(theme.colors.primary).setAlpha(0.08).rgbaString
                                    : "transparent",
                                marginBottom: 4,
                                borderRadius: 4,
                            }}>
                            <Text style={{fontWeight: isActive ? "bold" : "normal"}}>{t.courseName}</Text>
                            <Text style={{fontSize: 12, color: theme.colors.grey3}}>
                                {[t.teacher, t.venueName].filter(Boolean).join(" · ")}
                            </Text>
                        </UnPressable>
                    );
                })}
            </ScrollView>
        </>
    );
}

interface ConflictCourseSheetProps {
    courses: CourseClass[];
    onSelect: (course: CourseClass) => void;
    onPressActiveCourse: (course: CourseClass) => void;
}

export function ConflictCourseSheet({courses, onSelect, onPressActiveCourse}: ConflictCourseSheetProps) {
    const {store: conflictStore} = useConflictCourseStore();
    const courseCodes = courses.map(c => c._ori.courseName + "_" + c._ori.teacher).sort();
    const storedActive = conflictStore.getState().getActive(courseCodes);
    const activeCourseCode =
        storedActive ?? (courses[0] ? courses[0]._ori.courseName + "_" + courses[0]._ori.teacher : "");

    return (
        <ConflictCourseList
            courses={courses}
            activeCourseCode={activeCourseCode}
            onSelect={course => {
                conflictStore
                    .getState()
                    .setActive(courseCodes, course._ori.courseName + "_" + course._ori.teacher);
                onSelect(course);
            }}
            onPressActiveCourse={onPressActiveCourse}
        />
    );
}
