import {StyleSheet, View} from "react-native";
import {useCourseData} from "@/hooks/useCourseData.ts";
import {memo, useMemo} from "react";
import {Color} from "@/shared/color.ts";
import {UnPressable} from "@/components/un-ui";
import {Text, useTheme} from "@rneui/themed";
import {Icon} from "@/components/un-ui/Icon.tsx";
import {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";
import {useShallow} from "zustand/react/shallow";

interface HolidayItemProps {
    item: ScheduleTableItem;
    onPress?: (item: ScheduleTableItem) => void;
}

export const HolidayItem = memo(({item, onPress}: HolidayItemProps) => {
    const {store} = useCourseData();
    const timeSpanHeight = store(s => s.theme.timeSpanHeight);
    const courseItemMargin = store(s => s.theme.courseItemMargin);
    const {theme} = useTheme();

    const span = item.end - item.begin + 1;
    const y = item.begin - 1;

    const baseColor = "#10B981";
    const backgroundColor = Color(baseColor).setAlpha(0.12).rgbaString;
    const borderColor = baseColor;
    const textColor = Color.mix(baseColor, theme.colors.black, 0.7).rgbaString;

    // Dynamic layout based on span
    const isFullDay = span >= 8; // If holiday covers most of the day
    const isShort = span <= 2;

    const styles = useMemo(
        () =>
            StyleSheet.create({
                container: {
                    position: "absolute",
                    width: "96%",
                    marginHorizontal: "2%",
                    borderRadius: 6,
                    backgroundColor: backgroundColor,
                    height: timeSpanHeight * (timeSpanHeight <= 40 ? 14 : 13),
                    top: y * timeSpanHeight + courseItemMargin,
                    overflow: "hidden",
                    // Design change: Top accent border (like a sticky note) instead of left border
                    borderTopWidth: 4,
                    borderTopColor: borderColor,
                    justifyContent: "flex-start",
                    paddingTop: 16,
                    alignItems: "center",
                },
                watermark: {
                    position: "absolute",
                    top: isFullDay ? "20%" : -10,
                    right: isFullDay ? "10%" : -10,
                    opacity: 0.15,
                    transform: [{rotate: "-10deg"}],
                },
                text: {
                    textAlign: "center",
                    color: textColor,
                    fontSize: isFullDay ? 16 : 12, // Larger text for full-day holidays
                    zIndex: 1,
                    letterSpacing: 1,
                    fontWeight: "800",
                    textShadowColor: "rgba(0,0,0,0.05)",
                    textShadowOffset: {width: 0, height: 1},
                    textShadowRadius: 2,
                },
                subText: {
                    textAlign: "center",
                    color: textColor,
                    fontSize: 10,
                    opacity: 0.8,
                    marginTop: 2,
                    zIndex: 1,
                },
            }),
        [span, y, store(useShallow(s => s.theme)), baseColor, isFullDay, theme.mode],
    );

    return (
        <UnPressable
            style={styles.container}
            onPress={function () {
                return onPress?.(item);
            }}>
            {/* Watermark Icon - Scaled up for impact */}
            <View style={styles.watermark}>
                <Icon
                    name="party-popper"
                    style={{
                        fontSize: isFullDay ? 80 : 40,
                        color: baseColor,
                    }}
                />
            </View>

            <Text style={styles.text} numberOfLines={isShort ? 1 : 2}>
                {item.title}
            </Text>

            {!!item.subtitle && !isShort && (
                <Text style={styles.subText} numberOfLines={1}>
                    {item.subtitle}
                </Text>
            )}
        </UnPressable>
    );
});
