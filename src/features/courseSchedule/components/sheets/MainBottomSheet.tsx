import {UnBottomSheet} from "@/components/un-ui";
import {SheetState} from "@/features/courseSchedule/components/ScheduleCard.tsx";
import {MenuSheet} from "@/features/courseSchedule/components/sheets/MenuSheet.tsx";
import {SettingSheet} from "@/features/courseSchedule/components/sheets/SettingSheet.tsx";
import React, {useMemo} from "react";
import {usePagerView} from "react-native-pager-view";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {CourseDetailSheet} from "@/features/courseSchedule/components/sheets/CourseDetailSheet.tsx";
import {ConflictCourseSheet} from "@/features/courseSchedule/components/ConflictCourseList.tsx";
import {CustomEventsSheet} from "./CustomEventsSheet";
import type {useCustomEvents} from "../../hooks/useCustomEvents";

interface Props {
    sheet: SheetState;
    setSheet: (p: any) => void;
    examInfo?: ExamWithMeta[] | null;
    pageViewRest: Omit<ReturnType<typeof usePagerView>, "AnimatedPagerView" | "ref">;
    customEvents: ReturnType<typeof useCustomEvents>;
    year: number;
    term: 1 | 2;
    weekCount: number;
}

export const MainBottomSheet = ({
    sheet,
    setSheet,
    pageViewRest,
    examInfo,
    customEvents,
    year,
    term,
    weekCount,
}: Props) => {
    const courseExams = useMemo(() => {
        if (sheet.type !== "courseDetail" || !sheet.course || !examInfo) return [];
        return examInfo.filter(exam => exam.course === sheet.course.courseName);
    }, [sheet, examInfo]);

    const isVisible = sheet.type !== "closed";
    return (
        <UnBottomSheet
            isVisible={isVisible}
            onBackdropPress={() => {
                if (!customEvents.saving) setSheet({type: "closed"});
            }}
            containerStyle={{padding: "5%"}}>
            {sheet.type === "menu" && <MenuSheet setSheet={setSheet} />}
            {sheet.type === "setting" && <SettingSheet pageViewRest={pageViewRest} />}
            {sheet.type === "customEvents" && (
                <CustomEventsSheet
                    query={customEvents}
                    year={year}
                    term={term}
                    weekCount={weekCount || 20}
                    initialEventId={sheet.eventId}
                />
            )}
            {sheet.type === "courseDetail" && sheet.course && (
                <CourseDetailSheet course={sheet.course} examInfo={courseExams} />
            )}
            {sheet.type === "courseConflict" && (
                <ConflictCourseSheet
                    courses={sheet.courses}
                    onSelect={() => setSheet({type: "closed"})}
                    onPressActiveCourse={course => {
                        setSheet({
                            type: "courseDetail",
                            course: course._ori,
                        });
                    }}
                />
            )}
            {/*{sheet.type === "share" && (*/}
            {/*    <ScheduleShareSheet*/}
            {/*        week={pageViewRest.activePage + 1}*/}
            {/*        schedule={course}*/}
            {/*        startDay={startDay}*/}
            {/*        onClose={() => setSheet({type: "closed"})}*/}
            {/*    />*/}
            {/*)}*/}
        </UnBottomSheet>
    );
};
