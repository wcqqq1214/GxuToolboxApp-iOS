import {useNextEvent} from "@/features/courseSchedule/hooks/detail/useNextCourse.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {Text, useTheme} from "@rneui/themed";
import {Color} from "@/shared/color.ts";
import moment from "moment/moment";
import {StyleSheet, View} from "react-native";
import {switchByField} from "@/utils/objectUtils.ts";
import React from "react";

export function NextEventBanner() {
    const nextEvent = useNextEvent();
    const {startDay} = useStartDay();
    const {theme} = useTheme();
    const baseColor = theme.colors.primary;
    const backgroundColor = Color(baseColor).setAlpha(theme.mode === "light" ? 0.3 : 0.1).rgbaString;
    const textColor = Color.mix(baseColor, theme.colors.black, 0.5).rgbaString;

    const daysFromNow = (item: {week: number; day: number}) => {
        if (!startDay) return "未知时间";
        const eventDay = startDay
            .clone()
            .add(item.week - 1, "weeks")
            .add(item.day - 1, "days")
            .startOf("day");
        const diff = eventDay.diff(moment().startOf("day"), "days");
        if (diff <= 0) return "今天";
        if (diff === 1) return "明天";
        return `${diff}天后`;
    };

    const style = StyleSheet.create({
        container: {
            paddingHorizontal: 12,
            paddingVertical: 10,
            borderRadius: 8,
            marginHorizontal: 6,
            justifyContent: "center",
            alignItems: "center",
            backgroundColor: backgroundColor,
        },
    });

    if (!nextEvent && startDay) {
        const updateTime = startDay.clone().add(20, "week").format("MM月DD日");
        return (
            <View style={style.container}>
                <Text style={{fontSize: 16, color: textColor}}>所有活动已结束，将在{updateTime}更新至下个学期</Text>
            </View>
        );
    }

    return (
        <View style={style.container}>
            <Text style={{fontSize: 18, color: textColor}}>
                {switchByField(nextEvent, "kind", {
                    course: ev =>
                        `下节课：${ev.title}${ev.location ? ` · ${ev.location}` : ""} ${daysFromNow(ev).includes("后") ? `（${daysFromNow(ev)}）` : ""}`,
                    exam: ev => `下场考试：${ev.title}${ev.location ? ` · ${ev.location}` : ""}（${daysFromNow(ev)}）`,
                    holiday: ev => `下个假期：${ev.title}（${daysFromNow(ev)}）`,
                })}
            </Text>
        </View>
    );
}
