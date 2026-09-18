import React from "react";
import {ActivityIndicator, StyleSheet, View} from "react-native";
import {Button, useTheme} from "@rneui/themed";
import {UnText} from "@/components/un-ui";
import {DetailList} from "@/features/teachersInfo/components/DetailList.tsx";
import {useDetail} from "@/features/teachersInfo/hooks/useDetail.ts";
import type {TeacherStackParamList} from "@/features/teachersInfo/type/info.ts";
import type {NativeStackScreenProps} from "@react-navigation/native-stack";

type Props = NativeStackScreenProps<TeacherStackParamList, "Detail">;

/**
 * 编排教师详情页状态和内容，数据请求与详情分组分别由 hook、组件负责。
 */
export function DetailScreen({route}: Props) {
    const {theme} = useTheme();
    const {data, loading, error, retry} = useDetail(route.params.teacher);

    if (loading) {
        return (
            <View style={styles.state}>
                <ActivityIndicator color={theme.colors.primary} />
                <UnText size={16}>正在加载教师信息...</UnText>
            </View>
        );
    }

    if (error || !data) {
        return (
            <View style={styles.state}>
                <UnText size={16}>{error || "暂无教师信息"}</UnText>
                <Button onPress={retry}>重试</Button>
            </View>
        );
    }

    return <DetailList info={data} />;
}

const styles = StyleSheet.create({
    state: {
        flex: 1,
        alignItems: "center",
        justifyContent: "center",
        gap: 12,
        padding: 24,
    },
});
