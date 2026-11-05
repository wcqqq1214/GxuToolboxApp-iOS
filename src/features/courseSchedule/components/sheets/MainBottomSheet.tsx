import {UnBottomSheet} from "@/components/un-ui";
import {SheetState} from "@/features/courseSchedule/components/ScheduleCard.tsx";
import {MenuSheet} from "@/features/courseSchedule/components/sheets/MenuSheet.tsx";
import {SettingSheet} from "@/features/courseSchedule/components/sheets/SettingSheet.tsx";
import React, {useMemo} from "react";
import {usePagerView} from "react-native-pager-view";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {CourseDetailSheet} from "@/features/courseSchedule/components/sheets/CourseDetailSheet.tsx";

interface Props {
    sheet: SheetState;
    setSheet: (p: any) => void;
    examInfo?: ExamWithMeta[];
    pageViewRest: Omit<ReturnType<typeof usePagerView>, "AnimatedPagerView" | "ref">;
}

export const MainBottomSheet = ({sheet, setSheet, pageViewRest, examInfo}: Props) => {
    const courseExams = useMemo(() => {
        if (sheet.type !== "courseDetail" || !sheet.course || !examInfo) return [];
        return examInfo.filter(exam => exam.course === sheet.course.courseName);
    }, [sheet, examInfo]);

    const isVisible = sheet.type === "menu" || sheet.type === "setting" || sheet.type === "courseDetail";

    return (
        <UnBottomSheet
            isVisible={isVisible}
            onBackdropPress={() => setSheet({type: "closed"})}
            containerStyle={{padding: "5%"}}>
            {sheet.type === "menu" && <MenuSheet setSheet={setSheet} />}
            {sheet.type === "setting" && <SettingSheet pageViewRest={pageViewRest} />}
            {sheet.type === "courseDetail" && sheet.course && (
                <CourseDetailSheet course={sheet.course} examInfo={courseExams} />
            )}
        </UnBottomSheet>
    );
};
