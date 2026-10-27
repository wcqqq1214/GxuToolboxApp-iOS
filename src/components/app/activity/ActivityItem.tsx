import {PressableProps, StyleSheet, ViewStyle} from "react-native";
import {IActivity} from "@/type/app/activity.ts";
import React, {useMemo} from "react";
import {Text, useTheme} from "@rneui/themed";
import {Color} from "@/shared/color.ts";
import {UnPressable} from "@/components/un-ui";
import Flex from "@/components/un-ui/Flex.tsx";
import {useCourseData} from "@/hooks/useCourseData.ts";

interface ActivityItemProps extends Omit<PressableProps, "onPress" | "android_ripple"> {
    style?: ViewStyle;
    item: IActivity;
    onPress?: (item: IActivity) => void;
}

export function ActivityItem(props: ActivityItemProps) {
    const {store, courseScheduleStyle} = useCourseData();
    const timeSpanHeight = store(s => s.theme.timeSpanHeight);
    const weekdayHeight = store(s => s.theme.weekdayHeight);
    const courseItemMargin = store(s => s.theme.courseItemMargin);
    const {theme} = useTheme();
    const {item} = props;
    const span = item.timeSpan.reduceRight((pv, cv) => pv - cv) + 1;
    const y = item.timeSpan[0] - 1;
    const itemStyle = useMemo(() => {
        return StyleSheet.create({
            item: {
                height: span * timeSpanHeight - courseItemMargin * 2,
                position: "absolute",
                backgroundColor: Color(item.color ?? theme.colors.primary).setAlpha(theme.mode === "light" ? 0.3 : 0.1)
                    .rgbaString,
                top: y * timeSpanHeight,
                borderWidth: 2,
                borderColor: Color.mix(theme.colors.primary, theme.colors.white, 0.2).rgbaString,
            },
            text: {
                textAlign: "center",
                color: Color.mix(item.color ?? theme.colors.primary, theme.colors.black, 0.5).rgbaString,
            },
        });
    }, [item.color, courseItemMargin, timeSpanHeight, weekdayHeight, span, theme.colors.grey4, theme.mode, y]);
    return (
        // 课程元素
        <UnPressable
            onPress={function () {
                props.onPress?.(item);
            }}
            style={[props.style, courseScheduleStyle.courseItem, itemStyle.item]}>
            <Flex direction="column" gap={5}>
                <Text style={[itemStyle.text, {fontWeight: "bold"}]}>{item.name}</Text>
                {item.weekSpan[0] === item.weekSpan[1] ? (
                    <Text style={itemStyle.text}>仅第{item.weekSpan[0]}周</Text>
                ) : (
                    <Text style={itemStyle.text}>{item.weekSpan.join("-")}周</Text>
                )}
            </Flex>
        </UnPressable>
    );
}
