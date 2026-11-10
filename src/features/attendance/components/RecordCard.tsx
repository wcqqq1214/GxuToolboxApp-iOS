import {StyleSheet, Text, View} from "react-native";
import {useTheme} from "@rneui/themed";
import type {RecordPage} from "@gxutool/adapters/attendance";
import {AttendanceSystemType as AST} from "@/type/api/auth/attendanceSystem.ts";

type Record = RecordPage["items"][number];

export function RecordCard({record, showDivider = false}: {record: Record; showDivider?: boolean}) {
    const {theme} = useTheme();
    const detail = [record.periodLabel ?? record.periodRange, record.roomName].filter(Boolean).join(" · ");
    let statusColor = theme.colors.grey2;
    if (record.statusCode === AST.AttendanceState.Late) {
        statusColor = theme.colors.warning;
    } else if (record.statusCode === AST.AttendanceState.Absent) {
        statusColor = theme.colors.error;
    }

    return (
        <View style={[styles.row, {borderBottomColor: showDivider ? theme.colors.grey4 : "transparent"}]}>
            <View style={styles.main}>
                <Text style={[styles.course, {color: theme.colors.black}]} numberOfLines={1}>
                    {record.courseName}
                </Text>
                <Text style={[styles.status, {color: statusColor}]}>{record.statusName}</Text>
            </View>
            {detail ? (
                <Text style={[styles.detail, {color: theme.colors.grey2}]} numberOfLines={1}>
                    {detail}
                </Text>
            ) : null}
        </View>
    );
}

const styles = StyleSheet.create({
    row: {
        paddingHorizontal: 16,
        paddingVertical: 12,
        borderBottomWidth: StyleSheet.hairlineWidth,
    },
    main: {
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 12,
    },
    course: {
        flex: 1,
        fontSize: 15,
        fontWeight: "600",
    },
    status: {
        fontSize: 14,
        fontWeight: "700",
    },
    detail: {
        marginTop: 4,
        fontSize: 12,
    },
});
