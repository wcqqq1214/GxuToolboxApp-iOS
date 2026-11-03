import {Text, useTheme} from "@rneui/themed";
import {Color} from "@/shared/color.ts";
import moment from "moment/moment";
import {StyleSheet, View} from "react-native";
import {switchByField} from "@/utils/objectUtils.ts";
import React from "react";
import type {ScheduleTableItem} from "@/features/courseSchedule/type/schedule";

/** 只展示传入的日程，不独立加载课表或认证。 */
export function NextEventBanner({items, startDay, ready}: {
    items: ScheduleTableItem[];
    startDay: moment.Moment;
    ready: boolean;
}) {
    const now = moment();
    const timeSpans = ["08:00", "08:55", "10:00", "10:55", "14:30", "15:20", "16:25", "17:15", "18:10", "18:45", "19:40", "20:30", "21:20"];
    const nextEvent = items.map(item => {
        const [hour, minute] = (timeSpans[item.begin - 1] ?? "00:00").split(":").map(Number);
        return {item, date: startDay.clone().startOf("day").add((item.week - 1) * 7 + item.day - 1, "days").hour(hour).minute(minute)};
    }).filter(event => event.date.isAfter(now)).sort((a, b) => a.date.valueOf() - b.date.valueOf())[0]?.item;
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

    if (!ready || !nextEvent) return null;

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
