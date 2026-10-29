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
    /** 同楼栋首条只保留上圆角，末条只保留下圆角。 */
    firstInSection?: boolean;
    lastInSection?: boolean;
};

const PERIODS_LIST = Array.from({length: PERIODS}, (_, index) => index + 1);

type AvailabilityStateColors = {
    success: string;
    error: string;
    grey3: string;
};

/** 作用：生成时间条与图例共用的状态背景，确保两者透明度一致。 */
export function getRoomAvailabilityStateColors(mode: string, colors: AvailabilityStateColors) {
    const isLight = mode === "light";
    return {
        freeBackground: Color(colors.success).setAlpha(isLight ? 0.25 : 0.2).rgbaString,
        occupiedBackground: Color(colors.error).setAlpha(isLight ? 0.2 : 0.3).rgbaString,
        unknownBackground: Color(colors.grey3).setAlpha(isLight ? 0.1 : 0.2).rgbaString,
    };
}

/** 作用：展示一间教室在选中日期、节次范围内的空闲区间；只负责渲染，不查询数据。 */
export const RoomAvailabilityRow = memo(function RoomAvailabilityRow(props: RoomAvailabilityRowProps) {
    const {result, startPeriod, endPeriod, firstInSection = false, lastInSection = false} = props;
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
    const {freeBackground, occupiedBackground, unknownBackground} = getRoomAvailabilityStateColors(
        theme.mode,
        theme.colors,
    );
    const cardBackground = Color.mix(theme.colors.grey5, theme.colors.primary, 0.1).setAlpha(
        theme.mode === "light" ? 0.7 : 0.6,
    ).rgbaString;
    const timelineBackground = Color.mix(theme.colors.grey5, theme.colors.primary, 0.1).setAlpha(
        theme.mode === "light" ? 0.55 : 0.4,
    ).rgbaString;

    return (
        <View
            style={[
                styles.card,
                {
                    backgroundColor: cardBackground,
                },
                firstInSection && styles.firstCard,
                lastInSection && styles.lastCard,
            ]}
            accessible
            accessibilityLabel={`${result.room.name}，${rangeText}内空闲${freeText}节`}>
            <View style={styles.titleRow}>
                <View style={styles.titleContent}>
                    <UnText
                        size={14}
                        bold
                        numberOfLines={1}
                        adjustsFontSizeToFit
                        minimumFontScale={0.55}
                        style={styles.roomName}>
                        {result.room.name}
                    </UnText>
                    <UnText size={11} color={theme.colors.grey2} numberOfLines={1} style={styles.roomMeta}>
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
                        backgroundColor: timelineBackground,
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
                                          ? occupiedBackground
                                          : unknownBackground,
                                },
                                period < PERIODS && {
                                    borderRightColor: theme.colors.grey4,
                                    borderRightWidth: StyleSheet.hairlineWidth,
                                },
                            ]}>
                            <UnText
                                size={10}
                                color={free ? theme.colors.success : inRange ? theme.colors.error : theme.colors.grey3}
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
        padding: 8,
        gap: 6,
    },
    firstCard: {
        borderTopLeftRadius: 10,
        borderTopRightRadius: 10,
    },
    lastCard: {
        borderBottomLeftRadius: 10,
        borderBottomRightRadius: 10,
    },
    titleRow: {
        flexDirection: "row",
        alignItems: "center",
        gap: 8,
    },
    titleContent: {
        flex: 1,
        minWidth: 0,
        flexDirection: "row",
        alignItems: "center",
        gap: 6,
    },
    roomName: {
        flex: 1,
        minWidth: 0,
    },
    roomMeta: {
        flexShrink: 0,
    },
    timeline: {
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
