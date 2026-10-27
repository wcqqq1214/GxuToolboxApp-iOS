import {useUserConfig} from "@/hooks/useUserConfig.ts";
import React from "react";
import {useAttendance} from "@/features/courseSchedule/hooks/detail/useAttendance.ts";
import {ScrollView, StyleSheet} from "react-native";
import {Flex, NumberInput, vw} from "@/components/un-ui";
import {Text, useTheme} from "@rneui/themed";
import {TimeSchedule} from "@/components/tool/infoQuery/courseSchedule/TimeSchedule.tsx";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import {useScheduleTable} from "@/features/attendance/hooks/useScheduleTable.ts";
import {NewCourseItem} from "@/features/courseSchedule/components/NewCourseItem.tsx";
import {AttendanceSystemType as AST} from "@/type/api/auth/attendanceSystem.ts";

type SelectedTerm = {
    year: number;
    term: 1 | 2;
};

interface Props {
    selectedTerm: SelectedTerm | null;
}
export function TableScreen({selectedTerm}: Props) {
    const {store} = useUserConfig();
    const {theme} = useTheme();

    const {startDay, schedule, week, setWeek, totalWeeks} = useScheduleTable(selectedTerm);

    function getAttendanceColor(status: number | undefined, theme: ReturnType<typeof useTheme>["theme"]) {
        switch (status) {
            case AST.AttendanceState.Normal:
                return theme.colors.success;

            case AST.AttendanceState.Late:
            case AST.AttendanceState.Absent:
                return theme.colors.error;

            default:
                return theme.colors.primary;
        }
    }

    const devMode = store(s => s.devMode);
    const {update: updateAttendance} = useAttendance();

    const style = StyleSheet.create({
        container: {
            padding: vw(5),
        },
        tab: {
            width: "100%",
        },
    });

    return (
        <ScrollView contentContainerStyle={style.container}>
            <Flex>
                <Flex>
                    <Text>周数</Text>
                </Flex>
                <NumberInput value={week} onChange={setWeek} max={totalWeeks} min={1} />
            </Flex>
            <TimeSchedule<ScheduleTableItem>
                currentWeek={week}
                scheduleItems={[
                    {
                        data: schedule,
                        isItemShow: (item, day, targetWeek) =>
                            item.week === targetWeek && item.day === day.isoWeekday(),
                        itemRender: item => (
                            <NewCourseItem item={{...item, color: getAttendanceColor(item.status, theme)}} />
                        ),
                    },
                ]}
                startDay={startDay}
                showDate
                showDayHighlight
                showTimeSpanHighlight
            />
        </ScrollView>
    );
}
