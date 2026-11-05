import React, {useMemo} from "react";
import {ScrollView, StyleSheet, View} from "react-native";
import {Divider, useTheme} from "@rneui/themed";
import {UnText} from "@/components/un-ui";
import {DetailHeader} from "@/features/teachersInfo/components/DetailHeader.tsx";
import {buildSections} from "@/features/teachersInfo/utils/sections.ts";
import type {TeacherInfoDetail} from "@/features/teachersInfo/type/info";

/**
 * 展示教师详情分组，头部资料 + 若干「标题 / 正文」块。
 * @param info 教师详情数据
 */
export function DetailList({info}: {info: TeacherInfoDetail}) {
    const {theme} = useTheme();
    const sections = useMemo(() => buildSections(info), [info]);

    return (
        <View style={{flex: 1}}>
            <DetailHeader info={info} />
            <ScrollView style={{flex: 1}} contentContainerStyle={styles.list} showsVerticalScrollIndicator={false}>
                {sections.map(section => (
                    <View key={section.key} style={styles.section}>
                        <UnText size={18} style={[styles.title, {color: theme.colors.primary}]}>
                            {section.title}
                        </UnText>
                        <UnText size={16} style={styles.text}>
                            {section.text}
                        </UnText>
                        <Divider />
                    </View>
                ))}
            </ScrollView>
        </View>
    );
}

const styles = StyleSheet.create({
    list: {
        paddingBottom: 24,
    },
    section: {
        paddingHorizontal: 12,
        paddingBottom: 12,
        gap: 10,
    },
    title: {
        fontWeight: "bold",
        textAlign: "center",
    },
    text: {
        lineHeight: 24,
    },
});
