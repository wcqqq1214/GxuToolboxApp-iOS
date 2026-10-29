import {useState} from "react";
import {StyleSheet, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {UnPressable, UnText} from "@/components/un-ui";
import {PERIODS} from "../utils/constants";

export type PeriodRangeSelectorProps = {
    startPeriod: number;
    endPeriod: number;
    onChangeRange: (startPeriod: number, endPeriod: number) => void;
};

const PERIODS_LIST = Array.from({length: PERIODS}, (_, index) => index + 1);

/**
 * 作用：在单行 13 个小方块中连续选择节次范围。
 * 交互：第一次点击设置开始节，第二次点击设置结束节；两端顺序颠倒时自动归一为较小值到较大值。
 */
export function PeriodRangeSelector(props: PeriodRangeSelectorProps) {
    const {startPeriod, endPeriod, onChangeRange} = props;
    const {theme} = useTheme();
    const [pendingStart, setPendingStart] = useState<number | null>(null);

    const selectPeriod = (period: number) => {
        if (pendingStart === null) {
            setPendingStart(period);
            onChangeRange(period, Math.max(endPeriod, period));
            return;
        }

        onChangeRange(Math.min(pendingStart, period), Math.max(pendingStart, period));
        setPendingStart(null);
    };

    return (
        <View style={styles.section}>
            <View style={styles.titleRow}>
                <UnText size={13} bold>
                    节次范围
                </UnText>
                <UnText size={11} color={theme.colors.grey2}>
                    {pendingStart === null
                        ? `第 ${startPeriod}${startPeriod === endPeriod ? "" : `–${endPeriod}`} 节`
                        : `已选开始：第 ${pendingStart} 节，再点结束节`}
                </UnText>
            </View>
            <View
                style={[
                    styles.selector,
                    {
                        borderColor: theme.colors.grey4,
                        backgroundColor: theme.colors.grey5,
                    },
                ]}>
                {PERIODS_LIST.map(period => {
                    const selected = period >= startPeriod && period <= endPeriod;
                    const pending = pendingStart === period;
                    return (
                        <UnPressable
                            key={period}
                            onPress={() => selectPeriod(period)}
                            style={[
                                styles.cell,
                                {
                                    backgroundColor: selected ? theme.colors.primary : theme.colors.background,
                                    opacity: pending ? 0.65 : 1,
                                },
                                period < PERIODS && {
                                    borderRightColor: theme.colors.grey4,
                                    borderRightWidth: StyleSheet.hairlineWidth,
                                },
                            ]}
                            accessibilityLabel={`第 ${period} 节${selected ? "，已选择" : ""}`}>
                            <UnText
                                size={10}
                                bold={selected}
                                color={selected ? theme.colors.white : theme.colors.grey2}>
                                {period}
                            </UnText>
                        </UnPressable>
                    );
                })}
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    section: {
        gap: 6,
    },
    titleRow: {
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 8,
    },
    selector: {
        borderWidth: 1,
        borderRadius: 9,
        flexDirection: "row",
        overflow: "hidden",
    },
    cell: {
        flex: 1,
        minWidth: 0,
        height: 34,
        alignItems: "center",
        justifyContent: "center",
    },
});
