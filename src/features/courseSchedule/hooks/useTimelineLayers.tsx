import {useMemo} from "react";
import moment from "moment";
import {ScheduleTableItem, TimeScheduleItemData} from "@/features/courseSchedule/type/schedule.ts";
import {NewCourseItem} from "@/features/courseSchedule/components/NewCourseItem.tsx";
import {StackCourseItem} from "@/features/courseSchedule/components/StackCourseItem.tsx";
import {CourseClass} from "@/class/jw/course.ts";
import {useConflictCourseStore} from "@/features/courseSchedule/stores/useConflictCourseStore.ts";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {normalizeExam} from "@/features/courseSchedule/utils/normalizeExam.ts";
import {HolidayRange} from "@/features/courseSchedule/hooks/detail/useHoliday.ts";
import {HolidayItem} from "@/features/courseSchedule/components/HolidayItem.tsx";
import type {CustomEventOccurrence} from "../type/customEvent";

interface TimelineSource {
    courses: ScheduleTableItem[];
    holidays: ScheduleTableItem<HolidayRange, "holiday">[];
    exams?: ExamWithMeta[] | null;
    startDay: moment.Moment | null;
    customItems: CustomEventOccurrence[];
}

interface TimelineAction {
    onCoursePress: (item: ScheduleTableItem) => void;
    onExamPress: (exam: ExamWithMeta) => void;
    onConflictPress: (courses: CourseClass[], day: moment.Moment) => void;
    onCustomEventPress: (eventId: number) => void;
}

export function useTimelineLayers(
    source: TimelineSource,
    action: TimelineAction,
): TimeScheduleItemData<ScheduleTableItem>[] {
    const {store: conflictStore} = useConflictCourseStore();
    const {courses, holidays, exams, startDay, customItems} = source;
    const {onCoursePress, onExamPress, onConflictPress, onCustomEventPress} = action;

    // 1. 考试数据标准化（转换为带有网格时段的项）
    const examItems = useMemo(() => {
        if (!exams || !startDay) return [];
        return normalizeExam(exams, startDay);
    }, [exams, startDay]);

    return useMemo(() => {
        const layers: TimeScheduleItemData<ScheduleTableItem>[] = [];

        // 图层 1：假期图层（底图层：全天横幅，不参与调课）
        if (holidays.length > 0) {
            layers.push({
                data: holidays,
                needShift: false,
                isItemShow: (item, _day, week) => item.week === week && item.day === _day.isoWeekday(),
                // 假期条幅渲染
                itemRender: item => <HolidayItem item={item} />,
            });
        }

        // 图层 2：课程图层（核心图层：支持冲突折叠、参与调课、显示补课日前驱项）
        if (courses.length > 0) {
            layers.push({
                data: courses,
                avoidOverlap: true,
                needShift: true,
                showPreShiftItems: true,
                isItemShow: (item, _day, week) => item.week === week && item.day === _day.isoWeekday(),
                itemRender: item => <NewCourseItem item={item} onPress={() => onCoursePress(item)} />,
                isItemStack: (a, b) => a.begin <= b.end && b.begin <= a.end,
                stackRender: (items, day, _week, timeRange) => {
                    const parsedCourses = items.filter(i => i.raw).map(i => new CourseClass(i.raw));
                    if (parsedCourses.length === 0) return null;

                    const codes = parsedCourses.map(c => c._ori.courseName + "_" + c._ori.teacher).sort();
                    const activeKey =
                        conflictStore.getState().getActive(codes) ??
                        (parsedCourses[0]
                            ? parsedCourses[0]._ori.courseName + "_" + parsedCourses[0]._ori.teacher
                            : "");

                    return (
                        <StackCourseItem
                            course={parsedCourses}
                            activeCourse={activeKey}
                            timeRange={timeRange}
                            onPress={c => onConflictPress(c, day)}
                        />
                    );
                },
            });
        }

        // 图层 3：考试图层（顶图层：独立冲突域，优先显眼展示）
        if (examItems.length > 0) {
            layers.push({
                data: examItems,
                avoidOverlap: true,
                needShift: false, // 考试通常固定在特定日历日，不受普通调课影响
                isItemShow: (item, _day, week) => item.week === week && item.day === _day.isoWeekday(),
                itemRender: item => <NewCourseItem item={item} onPress={() => item.raw && onExamPress(item.raw)} />,
            });
        }

        if (customItems.length > 0) {
            layers.push({
                data: customItems,
                avoidOverlap: true,
                needShift: true,
                isItemShow: (item, day, week) => item.week === week && item.day === day.isoWeekday(),
                itemRender: item => (
                    <NewCourseItem
                        item={item}
                        onPress={() => onCustomEventPress((item as CustomEventOccurrence).eventId)}
                    />
                ),
            });
        }
        return layers;
    }, [
        courses,
        holidays,
        examItems,
        customItems,
        onCoursePress,
        onExamPress,
        onConflictPress,
        onCustomEventPress,
        conflictStore,
    ]);
}
