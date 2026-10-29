import {useRef, useState} from "react";
import {Modal, Pressable, StyleSheet, useWindowDimensions, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {Icon, UnPressable, UnText} from "@/components/un-ui";
import {Color} from "@/shared/color";
import {PERIODS} from "../utils/constants";

export type PeriodRangeSelectorProps = {
    startPeriod: number;
    endPeriod: number;
    onChangeRange: (startPeriod: number, endPeriod: number) => void;
};

const PERIODS_LIST = Array.from({length: PERIODS}, (_, index) => index + 1);
const PERIOD_TIMES = [
    ["08:00", "08:45"],
    ["08:55", "09:40"],
    ["10:00", "10:45"],
    ["10:55", "11:40"],
    ["14:30", "15:15"],
    ["15:20", "16:05"],
    ["16:25", "17:10"],
    ["17:15", "18:00"],
    ["18:10", "18:55"],
    ["18:45", "19:30"],
    ["19:40", "20:25"],
    ["20:30", "21:15"],
    ["21:20", "22:05"],
] as const;

type DropdownAnchor = {
    left: number;
    top: number;
    width: number;
};

/** 收起时显示已应用范围，展开后连续点击起始节和结束节完成选择。 */
export function PeriodRangeSelector(props: PeriodRangeSelectorProps) {
    const {startPeriod, endPeriod, onChangeRange} = props;
    const {theme} = useTheme();
    const {height: windowHeight} = useWindowDimensions();
    const [expanded, setExpanded] = useState(false);
    const [anchor, setAnchor] = useState<DropdownAnchor | null>(null);
    const [pendingStart, setPendingStart] = useState<number | null>(null);
    const [draftStart, setDraftStart] = useState(startPeriod);
    const [draftEnd, setDraftEnd] = useState(endPeriod);
    const triggerRef = useRef<View>(null);

    const formatRange = (start: number, end: number) =>
        start === end ? `第 ${start} 节` : `第 ${start} 节 至 第 ${end} 节`;
    const timeRange =
        PERIOD_TIMES[startPeriod - 1] && PERIOD_TIMES[endPeriod - 1]
            ? `${PERIOD_TIMES[startPeriod - 1][0]}–${PERIOD_TIMES[endPeriod - 1][1]}`
            : "";

    const closeExpanded = () => {
        setExpanded(false);
        setPendingStart(null);
    };
    const toggleExpanded = () => {
        if (expanded) {
            closeExpanded();
            return;
        }
        triggerRef.current?.measureInWindow((left, top, width, height) => {
            const dropdownTop = top + height + 6;
            const estimatedPanelHeight = 92;
            setAnchor({
                left,
                top:
                    windowHeight - dropdownTop >= estimatedPanelHeight + 12
                        ? dropdownTop
                        : Math.max(12, top - estimatedPanelHeight - 6),
                width,
            });
            setDraftStart(startPeriod);
            setDraftEnd(endPeriod);
            setPendingStart(null);
            setExpanded(true);
        });
    };

    const selectPeriod = (period: number) => {
        if (pendingStart === null) {
            setPendingStart(period);
            setDraftStart(period);
            setDraftEnd(period);
            return;
        }

        const nextStart = Math.min(pendingStart, period);
        const nextEnd = Math.max(pendingStart, period);
        setDraftStart(nextStart);
        setDraftEnd(nextEnd);
        onChangeRange(nextStart, nextEnd);
        setPendingStart(null);
        setExpanded(false);
    };

    const selectorBackground = Color(theme.colors.grey5)
        .setAlpha(theme.mode === "light" ? 0.7 : 0.55)
        .rgbaString;
    const selectedBackground = Color(theme.colors.primary)
        .setAlpha(theme.mode === "light" ? 0.72 : 0.65)
        .rgbaString;
    const floatingBackground = Color.mix(
        theme.colors.background,
        theme.colors.primary,
        theme.mode === "light" ? 0.1 : 0.22,
    ).rgbaString;
    const floatingBorder = Color.mix(theme.colors.grey4, theme.colors.primary, 0.12).rgbaString;
    const floatingShadow = Color.mix(theme.colors.grey2, theme.colors.primary, 0.24)
        .setAlpha(0.42)
        .rgbaString;

    return (
        <View style={styles.section}>
            <View ref={triggerRef} collapsable={false}>
                <UnPressable
                    onPress={toggleExpanded}
                    style={[
                        styles.field,
                        {
                            backgroundColor: selectorBackground,
                            borderColor: theme.colors.grey4,
                        },
                    ]}
                    accessibilityLabel={`节次范围，${formatRange(startPeriod, endPeriod)}${timeRange ? `，${timeRange}` : ""}`}>
                    <View style={styles.fieldLabel}>
                        <UnText size={14} numberOfLines={1} style={styles.fieldText}>
                            {formatRange(startPeriod, endPeriod)}
                        </UnText>
                        {!!timeRange && (
                            <UnText size={11} numberOfLines={1} color={theme.colors.grey3}>
                                {timeRange}
                            </UnText>
                        )}
                    </View>
                    <Icon
                        name={expanded ? "chevron-up" : "chevron-down"}
                        size={18}
                        color={theme.colors.grey2}
                    />
                </UnPressable>
            </View>

            <Modal
                visible={expanded && anchor !== null}
                transparent
                animationType="none"
                statusBarTranslucent
                onRequestClose={closeExpanded}>
                <View style={styles.modalRoot}>
                    <Pressable style={styles.backdrop} onPress={closeExpanded} />
                    {anchor && (
                        <View
                            style={[
                                styles.dropdown,
                                {
                                    top: anchor.top,
                                    left: anchor.left,
                                    width: anchor.width,
                                    backgroundColor: floatingBackground,
                                    shadowColor: floatingShadow,
                                },
                            ]}>
                            <View style={[styles.dropdownSurface, {borderColor: floatingBorder}]}>
                                <UnText size={11} color={theme.colors.grey2}>
                                    {pendingStart === null
                                        ? "先选择起始节"
                                        : `已选第 ${pendingStart} 节，再选择结束节`}
                                </UnText>
                                <View
                                    style={[
                                        styles.selector,
                                        {borderColor: floatingBorder, backgroundColor: selectorBackground},
                                    ]}>
                                    {PERIODS_LIST.map(period => {
                                        const selected = period >= draftStart && period <= draftEnd;
                                        const pending = pendingStart === period;
                                        return (
                                            <UnPressable
                                                key={period}
                                                onPress={() => selectPeriod(period)}
                                                style={[
                                                    styles.cell,
                                                    {
                                                        backgroundColor: selected
                                                            ? selectedBackground
                                                            : "transparent",
                                                        opacity: pending ? 0.72 : 1,
                                                    },
                                                    period < PERIODS && {
                                                        borderRightColor: floatingBorder,
                                                        borderRightWidth: StyleSheet.hairlineWidth,
                                                    },
                                                ]}
                                                accessibilityLabel={`第 ${period} 节${selected ? "，已选择" : ""}`}>
                                                <UnText
                                                    size={10}
                                                    bold={selected}
                                                    color={
                                                        selected ? theme.colors.white : theme.colors.grey2
                                                    }>
                                                    {period}
                                                </UnText>
                                            </UnPressable>
                                        );
                                    })}
                                </View>
                            </View>
                        </View>
                    )}
                </View>
            </Modal>
        </View>
    );
}

const styles = StyleSheet.create({
    section: {
        gap: 6,
    },
    field: {
        minHeight: 40,
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 12,
        flexDirection: "row",
        alignItems: "center",
        gap: 10,
    },
    fieldText: {
        flexShrink: 1,
    },
    fieldLabel: {
        flex: 1,
        minWidth: 0,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        gap: 8,
    },
    modalRoot: {
        flex: 1,
    },
    backdrop: {
        ...StyleSheet.absoluteFillObject,
    },
    dropdown: {
        position: "absolute",
        borderRadius: 12,
        zIndex: 1000,
        elevation: 12,
        shadowOffset: {width: 0, height: 4},
        shadowOpacity: 0.2,
        shadowRadius: 8,
    },
    dropdownSurface: {
        borderWidth: 1,
        borderRadius: 12,
        padding: 10,
        gap: 6,
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
