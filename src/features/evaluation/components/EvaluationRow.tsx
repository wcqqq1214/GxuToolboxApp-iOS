import {Row} from "react-native-reanimated-table";
import {StyleSheet, TouchableOpacity} from "react-native";
import {useTheme} from "@rneui/themed";
import React from "react";
import {Evaluation} from "@/features/evaluation/types/evaluation.type.ts";
import {EvaTeacherList} from "@/features/evaluation/types/schema/TeacherList.ts";

interface EvaluationRowProps {
    item: EvaTeacherList;
    onPress: (item: Evaluation) => void;
    colWidths: number[];
    colorMap: Record<string, string>;
}

const EvaluationRowComponent = ({item, onPress, colorMap}: EvaluationRowProps) => {
    const {theme} = useTheme();
    const colWidths = [12, 6, 5];
    const styles = StyleSheet.create({
        row: {
            height: "auto",
            borderBottomWidth: StyleSheet.hairlineWidth,
            borderBottomColor: theme.colors.divider,
            alignItems: "center",
            paddingVertical: 14,
        },
        rowText: {
            textAlign: "center",
            fontSize: 14,
        },
    });

    return (
        <TouchableOpacity onPress={() => onPress(item)}>
            <Row
                cellTextStyle={cell => ({color: colorMap[cell] ?? theme.colors.black})}
                data={[`${item.courseName}(${item.courseTypeName})`, item.teacherName, item.submitStatus]}
                style={styles.row}
                flexArr={colWidths}
                textStyle={styles.rowText}
            />
        </TouchableOpacity>
    );
};

export const EvaluationRow = React.memo(EvaluationRowComponent);
