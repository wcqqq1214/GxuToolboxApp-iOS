import {StyleSheet, Text, View} from "react-native";
import {Icon, UnPressable, UnText} from "@/components/un-ui";
import {Divider, useTheme} from "@rneui/themed";
import {useNavigation} from "@react-navigation/native";
import {AuthStateMap} from "@/core/auth/auth.type.ts";

import {useAttendanceAuth} from "@/core/auth/attendance/hooks/useAttendanceAuth.ts";
import {useJwAuth} from "@/core/auth/Jw/hooks/useJwAuth.ts";
import {useUnifiedAuth} from "@/core/auth/unified/hook/useUnifiedAuth.ts";
import {SheetState} from "@/features/courseSchedule/components/ScheduleCard.tsx";

export const MenuSheet = ({setSheet}: {setSheet: (s: SheetState) => void}) => {
    const {theme} = useTheme();

    const navigation = useNavigation<any>();

    const {authState: JWAuthState} = useJwAuth();
    const {authState: unifiedAuthState} = useUnifiedAuth();
    const {authState: attendanceAuthState} = useAttendanceAuth();

    const authItems = [
        {label: "教务系统", icon: "school", auth: JWAuthState, screen: "jwAccount"},
        {label: "统一认证", icon: "shield-account", auth: unifiedAuthState, screen: "authAccount"},
        {label: "考勤系统", icon: "clock-check", auth: attendanceAuthState, screen: "attendanceAccount"},
    ];

    const actionItems = [
        {label: "事件编辑", icon: {name: "table-edit"}, onPress: () => setSheet({type: "closed"})},
        {label: "分享课表", icon: {type: "antdesign", name: "share-alt"}, onPress: () => setSheet({type: "share"})},
        {label: "课表设置", icon: {name: "cog"}, onPress: () => setSheet({type: "setting"})},
    ];

    const styles = StyleSheet.create({
        menuItem: {
            flexDirection: "row",
            gap: 16,
            paddingVertical: 14,
            paddingHorizontal: 8,
            alignItems: "center",
            borderBottomWidth: StyleSheet.hairlineWidth,
            borderBottomColor: theme.colors.greyOutline,
        },
        gridContainer: {
            flexDirection: "row",
            flexWrap: "wrap",
        },
        gridItem: {
            flex: 1,
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            gap: 8,
            paddingVertical: 14,
        },
    });

    return (
        <View>
            <Text style={{fontSize: 14, color: theme.colors.grey3, paddingHorizontal: 8, paddingBottom: 4}}>
                账号状态 | 可跳转至对应登录页
            </Text>
            <View style={styles.gridContainer}>
                {authItems.map(item => (
                    <UnPressable
                        key={item.label}
                        style={styles.gridItem}
                        onPress={() => {
                            setSheet({type: "closed"});
                            navigation.navigate("setting", {screen: item.screen});
                        }}>
                        <Icon
                            name={item.icon}
                            size={24}
                            color={
                                item.auth?.status === AuthStateMap.Authenticated
                                    ? theme.colors.success
                                    : theme.colors.error
                            }
                        />
                        <UnText>{item.label}</UnText>
                    </UnPressable>
                ))}
            </View>
            <Divider />
            <View style={styles.gridContainer}>
                {actionItems.map(item => (
                    <UnPressable key={item.label} onPress={item.onPress} style={styles.gridItem}>
                        <Icon {...item.icon} size={24} />
                        <UnText>{item.label}</UnText>
                    </UnPressable>
                ))}
            </View>
        </View>
    );
};
