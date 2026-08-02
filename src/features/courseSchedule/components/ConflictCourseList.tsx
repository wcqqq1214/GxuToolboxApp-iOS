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
                    const t = c.transformed;
                    const isActive = t.courseCode + "_" + t.staffId === activeCourseCode;
                    return (
                        <UnPressable
                            key={t.courseCode + "_" + t.staffId}
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
                                {[t.name, t.venueName].filter(Boolean).join(" · ")}
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
    const courseCodes = courses.map(c => c.transformed.courseCode + "_" + c.transformed.staffId).sort();
    const storedActive = conflictStore.getState().getActive(courseCodes);
    const activeCourseCode =
        storedActive ?? (courses[0] ? courses[0].transformed.courseCode + "_" + courses[0].transformed.staffId : "");

    return (
        <ConflictCourseList
            courses={courses}
            activeCourseCode={activeCourseCode}
            onSelect={course => {
                conflictStore
                    .getState()
                    .setActive(courseCodes, course.transformed.courseCode + "_" + course.transformed.staffId);
                onSelect(course);
            }}
            onPressActiveCourse={onPressActiveCourse}
        />
    );
}
