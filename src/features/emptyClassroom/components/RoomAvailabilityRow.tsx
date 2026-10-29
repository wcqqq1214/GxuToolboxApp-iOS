import {memo, useMemo} from "react";
import {StyleSheet, View} from "react-native";
import {useTheme} from "@rneui/themed";
import {UnText} from "@/components/un-ui";
import {Color} from "@/shared/color";
import type {RoomAvailabilityResult} from "../type";
import {PERIODS} from "../utils/constants";
import {detectFloor} from "../utils/floor";

export type RoomAvailabilityRowProps = {
    result: RoomAvailabilityResult;
    startPeriod: number;
    endPeriod: number;
};

const PERIODS_LIST = Array.from({length: PERIODS}, (_, index) => index + 1);

/** 作用：展示一间教室在选中日期、节次范围内的空闲区间；只负责渲染，不查询数据。 */
export const RoomAvailabilityRow = memo(function RoomAvailabilityRow(props: RoomAvailabilityRowProps) {
    const {result, startPeriod, endPeriod} = props;
    const {theme} = useTheme();
    const freePeriods = useMemo(
        () =>
            new Set(
                result.freeRuns.flatMap(run =>
                    Array.from({length: run.end - run.begin + 1}, (_, index) => run.begin + index),
                ),
            ),
        [result.freeRuns],
    );

    const floor = detectFloor(result.room.name, result.room.building);
    const meta = [
        floor === null ? "其他楼层" : `${floor} 层`,
        result.room.placeType,
        result.room.seatCount === null ? "" : `${result.room.seatCount} 座`,
    ]
        .filter(Boolean)
        .join(" · ");
    const rangeText = startPeriod === endPeriod ? `第${startPeriod}节` : `第${startPeriod}–${endPeriod}节`;
    const freeText = result.freeRuns
        .map(run => (run.begin === run.end ? `${run.begin}` : `${run.begin}–${run.end}`))
        .join("、");
    const rangeBackground = Color(theme.colors.primary)
        .setAlpha(theme.mode === "light" ? 0.08 : 0.12)
        .rgbaString;
    const freeBackground = Color(theme.colors.success).setAlpha(theme.mode === "light" ? 0.24 : 0.18).rgbaString;

    return (
        <View
            style={[styles.card, {backgroundColor: theme.colors.grey5, borderColor: theme.colors.grey4}]}
            accessible
            accessibilityLabel={`${result.room.name}，${rangeText}内空闲${freeText}节`}>
            <View style={styles.titleRow}>
                <View style={styles.titleContent}>
                    <UnText size={15} bold numberOfLines={1}>
                        {result.room.name}
                    </UnText>
                    <UnText size={11} color={theme.colors.grey2} numberOfLines={1}>
                        {meta}
                    </UnText>
                </View>
                <UnText size={12} color={theme.colors.success} bold>
                    {`空闲 ${result.freePeriodCount} 节`}
                </UnText>
            </View>

            <View
                style={[
                    styles.timeline,
                    {
                        backgroundColor: theme.colors.background,
                        borderColor: theme.colors.grey4,
                    },
                ]}>
                {PERIODS_LIST.map(period => {
                    const free = freePeriods.has(period);
                    const inRange = period >= startPeriod && period <= endPeriod;
                    return (
                        <View
                            key={period}
                            style={[
                                styles.periodCell,
                                {
                                    backgroundColor: free
                                        ? freeBackground
                                        : inRange
                                          ? rangeBackground
                                          : theme.colors.background,
                                },
                                period < PERIODS && {
                                    borderRightColor: theme.colors.grey4,
                                    borderRightWidth: StyleSheet.hairlineWidth,
                                },
                            ]}>
                            <UnText
                                size={10}
                                color={free ? theme.colors.success : inRange ? theme.colors.grey2 : theme.colors.grey3}
                                bold={free}>
                                {period}
                            </UnText>
                        </View>
                    );
                })}
            </View>
        </View>
    );
});

const styles = StyleSheet.create({
    card: {
        borderWidth: StyleSheet.hairlineWidth,
        borderRadius: 10,
        padding: 10,
        gap: 8,
    },
    titleRow: {
        flexDirection: "row",
        alignItems: "flex-start",
        gap: 10,
    },
    titleContent: {
        flex: 1,
        minWidth: 0,
        gap: 2,
    },
    timeline: {
        borderWidth: 1,
        borderRadius: 9,
        flexDirection: "row",
        alignItems: "stretch",
        overflow: "hidden",
    },
    periodCell: {
        flex: 1,
        minWidth: 0,
        height: 34,
        alignItems: "center",
        justifyContent: "center",
    },
});
