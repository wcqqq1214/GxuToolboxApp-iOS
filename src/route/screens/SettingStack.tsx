import React, {lazy} from "react";
import {createNativeStackNavigator} from "@react-navigation/native-stack";
import {Color} from "@/shared/color.ts";
import {Button, useTheme} from "@rneui/themed";
import {useNavigation} from "@react-navigation/native";
import {useWebView} from "@/hooks/app.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";

const Stack = createNativeStackNavigator();

export function SettingStack() {
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const bgOpacity = store(s => s.theme.bgOpacity);
    const navigation = useNavigation();
    const {openInJw} = useWebView();
    const headerRightEle = () => {
        return (
            <Button
                type="clear"
                containerStyle={{marginRight: 10}}
                onPress={() => {
                    openInJw("/xtgl/index_initMenu.html");
                }}>
                打开教务
            </Button>
        );
    };
    return (
        <Stack.Navigator
            initialRouteName="settingIndex"
            screenOptions={{
                headerShadowVisible: false,
                headerStyle: {
                    backgroundColor: Color.mix(theme.colors.background, theme.colors.primary, 0.2).setAlpha(
                        ((theme.mode === "dark" ? 0.7 : 0.9) * bgOpacity) / 100,
                    ).rgbaString,
                },
                contentStyle: {
                    backgroundColor: Color(theme.colors.background).setAlpha(
                        ((theme.mode === "dark" ? 0.5 : 0.6) * bgOpacity) / 100,
                    ).rgbaString,
                },
                animation: "fade",
                animationDuration: 100,
                headerRight: headerRightEle,
            }}>
            <Stack.Screen
                name="settingIndex"
                component={lazy(() =>
                    import("@/screens/setting/SettingIndex.tsx").then(m => ({default: m.SettingIndex})),
                )}
                options={{
                    title: "工具箱设置",
                    contentStyle: {
                        backgroundColor: "transparent",
                    },
                }}
            />
            <Stack.Screen
                name="userPreferenceSetting"
                component={lazy(() =>
                    import("@/screens/setting/account/preference/UserPreferenceSettingIndex.tsx").then(m => ({
                        default: m.UserPreferenceSettingIndex,
                    })),
                )}
                options={{
                    title: "偏好设置",
                    headerStyle: {
                        backgroundColor: Color(theme.colors.background).setAlpha(
                            ((theme.mode === "dark" ? 0.5 : 0.4) * bgOpacity) / 100,
                        ).rgbaString,
                    },
                    contentStyle: {
                        backgroundColor: "transparent",
                    },
                }}
            />

            {/*  账号相关  */}
            <Stack.Screen
                name="personalInfo"
                component={lazy(() =>
                    import("@/features/personalInfo/screen/PersonalInfo.tsx").then(m => ({default: m.PersonalInfo})),
                )}
                options={{title: "查看个人信息"}}
            />
            <Stack.Screen
                name="jwAccount"
                component={lazy(() =>
                    import("@/screens/setting/account/JWAccountScreen.tsx").then(m => ({default: m.JWAccountScreen})),
                )}
                options={{title: "登录教务系统"}}
            />
            <Stack.Screen
                name="authAccount"
                component={lazy(() =>
                    import("@/screens/setting/account/AuthAccountScreen.tsx").then(m => ({
                        default: m.AuthAccountScreen,
                    })),
                )}
                options={{title: "统一认证系统账号设置"}}
            />
            <Stack.Screen
                name="attendanceSystemAccount"
                component={lazy(() =>
                    import("@/screens/setting/account/AttendanceSystemAccountScreen.tsx").then(m => ({
                        default: m.AttendanceSystemAccountScreen,
                    })),
                )}
                options={{title: "考勤系统账号设置"}}
            />

            {/*  偏好设置  */}
            <Stack.Screen
                name="CourseItemDetailSetting"
                component={lazy(() =>
                    import("@/screens/setting/account/preference/CourseItemDetailSettingScreen.tsx").then(m => ({
                        default: m.CourseItemDetailSettingScreen,
                    })),
                )}
                options={{title: "课程元素详情显示"}}
            />
            <Stack.Screen
                name="ExamItemDetailSetting"
                component={lazy(() =>
                    import("@/screens/setting/account/preference/ExamItemDetailSettingScreen.tsx").then(m => ({
                        default: m.ExamItemDetailSettingScreen,
                    })),
                )}
                options={{title: "考试元素详情显示"}}
            />
            <Stack.Screen
                name="versionList"
                component={lazy(() =>
                    import("@/screens/setting/VersionListScreen.tsx").then(m => ({
                        default: m.VersionListScreen,
                    })),
                )}
                options={{
                    title: "软件版本",
                    headerStyle: {
                        backgroundColor: Color(theme.colors.background).setAlpha(
                            ((theme.mode === "dark" ? 0.5 : 0.4) * bgOpacity) / 100,
                        ).rgbaString,
                    },
                    contentStyle: {backgroundColor: "transparent"},
                }}
            />
            <Stack.Screen
                name="otaList"
                component={lazy(() =>
                    import("@/screens/setting/OTAListScreen.tsx").then(m => ({
                        default: m.OTAListScreen,
                    })),
                )}
                options={{
                    title: "代码版本",
                    headerStyle: {
                        backgroundColor: Color(theme.colors.background).setAlpha(
                            ((theme.mode === "dark" ? 0.5 : 0.4) * bgOpacity) / 100,
                        ).rgbaString,
                    },
                    contentStyle: {backgroundColor: "transparent"},
                }}
            />
        </Stack.Navigator>
    );
}
