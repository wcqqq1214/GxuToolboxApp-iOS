import * as React from "react";
import {useEffect, useState} from "react";
import {ScrollView, StyleSheet, Text, View} from "react-native";
import {WidgetPreview} from "react-native-android-widget";
import {useTheme} from "@rneui/themed";

import {CourseScheduleWidget} from "@/features/widget/CourseScheduleWidget";
import {getWidgetSchedule, type WidgetScheduleData} from "@/features/widget/widgetScheduleData";
import {onPersonalScheduleChanged} from "@/features/widget/widgetStore";

const PREVIEW_WIDTH = 370;
const PREVIEW_HEIGHT = 370;

export function WidgetPreviewScreen() {
    const {theme} = useTheme();
    const [data, setData] = useState<WidgetScheduleData | null>(null);

    useEffect(() => {
        const reload = () => getWidgetSchedule().then(setData);
        reload();
        const subscription = onPersonalScheduleChanged(reload);
        return () => subscription.remove();
    }, []);

    if (!data) return null;

    return (
        <View style={styles.container}>
            <WidgetPreview
                renderWidget={() => (
                    <CourseScheduleWidget
                        theme={theme.mode}
                        data={data}
                        width={PREVIEW_WIDTH}
                        height={PREVIEW_HEIGHT}
                    />
                )}
                width={PREVIEW_WIDTH}
                height={PREVIEW_HEIGHT}
            />
            <ScrollView style={styles.details}>
                <Text style={styles.text}>课程表小组件预览</Text>
                <Text style={styles.text}>
                    {data.next
                        ? `下一节：${data.next.name} · ${data.next.date} ${data.next.beginTime}`
                        : "当前学期没有后续课程"}
                </Text>
            </ScrollView>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        alignItems: "center",
        justifyContent: "center",
    },
    details: {
        backgroundColor: "white",
        width: "90%",
        borderRadius: 10,
        marginTop: 20,
        padding: 10,
    },
    text: {
        color: "black",
        fontSize: 15,
        marginTop: 10,
    },
});
