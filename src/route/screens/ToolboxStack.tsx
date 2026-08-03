import React, {lazy} from "react";
import {createNativeStackNavigator} from "@react-navigation/native-stack";
import {Color} from "@/shared/color.ts";
import {Button, useTheme} from "@rneui/themed";
import {useWebView} from "@/hooks/app.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {RescheduleNotificationScreen} from "@/features/notification/screen/RescheduleNotificationScreen.tsx";

const Stack = createNativeStackNavigator();

export function ToolboxStack() {
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const bgOpacity = store(s => s.theme.bgOpacity);
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
            initialRouteName="toolboxIndex"
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
                name="toolboxIndex"
                component={lazy(() => import("@/screens/tool/ToolboxIndex.tsx").then(m => ({default: m.ToolboxIndex})))}
                options={{
                    title: "工具箱",
                    contentStyle: {
                        backgroundColor: "transparent",
                    },
                }}
            />

            {/*  工具  */}
            <Stack.Screen
                name="courseScheduleQuery"
                component={lazy(() =>
                    import("@/screens/tool/jw/infoQuery/courseSchedule/CourseScheduleQuery.tsx").then(m => ({
                        default: m.CourseScheduleQuery,
                    })),
                )}
                options={{title: "课表查询"}}
            />
            <Stack.Screen
                name="classCourseSchedule"
                component={lazy(() =>
                    import("@/features/classCourseSchedule/screen/ClassCourseSchedule.tsx").then(m => ({
                        default: m.ClassCourseSchedule,
                    })),
                )}
                options={{title: "班级课表查询"}}
            />
            <Stack.Screen
                name="AttendanceInfoQueryScreen"
                component={lazy(() =>
                    import("@/screens/tool/auth/attendanceSystem/AttendanceInfoQueryScreen.tsx").then(m => ({
                        default: m.default,
                    })),
                )}
                options={{title: "考勤信息查询"}}
            />

            <Stack.Screen
                name="examInfo"
                component={lazy(() =>
                    import("@/features/examInfo/screens/ExamInfo.tsx").then(m => ({default: m.ExamInfo})),
                )}
                options={{title: "考试信息查询"}}
            />
            <Stack.Screen
                name="examScore"
                component={lazy(() =>
                    import("@/features/examScore/screen/ExamScore.tsx").then(m => ({default: m.ExamScore})),
                )}
                options={{title: "考试成绩查询"}}
            />
            <Stack.Screen
                name="gpaCalculator"
                component={lazy(() =>
                    import("@/features/examScore/screen/GPAcalculator.tsx").then(m => ({default: m.GPAcalculator})),
                )}
                options={{title: "GPA计算器"}}
            />
            <Stack.Screen
                name="SelfSelectedCourse"
                component={lazy(() =>
                    import("@/screens/tool/jw/courseSelection/SelfCourseSelection.tsx").then(m => ({
                        default: m.SelfCourseSelection,
                    })),
                )}
                options={{title: "自主选课"}}
            />
            <Stack.Screen
                name="courseSelectionList"
                component={lazy(() => import("@/screens/tool/jw/courseSelection/CourseSelectionList.tsx"))}
                options={{title: "选课课程列表查询"}}
            />
            <Stack.Screen
                name="ElectiveStrategy"
                component={lazy(() => import("@/features/electiveStrategy/screen/ElectiveStrategy"))}
                options={{title: "校选课查漏"}}
            />
            <Stack.Screen
                name="TeacherQueryInfoScreen"
                component={lazy(() =>
                    import("@/screens/tool/other/teacherInfo/TeacherInfoScreen.tsx").then(m => ({
                        default: m.TeacherQueryInfoScreen,
                    })),
                )}
                options={{title: "教师信息查询"}}
            />

            <Stack.Screen
                name="phyExpScreen"
                component={lazy(() =>
                    import("@/screens/tool/jw/infoQuery/praticalCourse/PhyExpScreen.tsx").then(m => ({
                        default: m.PhyExpScreen,
                    })),
                )}
                options={{title: "物理实验课查询"}}
            />
            <Stack.Screen
                name="engTrainingScheduleScreen"
                component={lazy(() =>
                    import("@/screens/tool/jw/infoQuery/praticalCourse/EngTrainingScheduleScreen.tsx").then(m => ({
                        default: m.EngTrainingScheduleScreen,
                    })),
                )}
                options={{title: "金工实训查询"}}
            />

            <Stack.Screen
                name="reschedulingNews"
                component={RescheduleNotificationScreen}
                options={{title: "调课信息查询"}}
            />
            <Stack.Screen
                name="timeShiftScreen"
                component={lazy(() =>
                    import("@/screens/tool/jw/notification/TimeShiftScreen.tsx").then(m => ({
                        default: m.TimeShiftScreen,
                    })),
                )}
                options={{title: "调休信息查询"}}
            />
            <Stack.Screen
                name="HolidayScreen"
                component={lazy(() =>
                    import("@/features/holidays/screen/HolidayScreen.tsx").then(m => ({default: m.HolidayScreen})),
                )}
                options={{title: "假期安排"}}
            />
            <Stack.Screen
                name="MainScreen"
                component={lazy(() =>
                    import("@/features/documents/screen/MainScreen.tsx").then(m => ({default: m.MainScreen})),
                )}
                options={{title: "学校文件"}}
            />

            <Stack.Screen
                name="EvaluationOverview"
                component={lazy(() =>
                    import("@/features/evaluation/screens/EvaluationOverview.tsx").then(m => ({
                        default: m.EvaluationOverview,
                    })),
                )}
                options={{title: "期末学生评价"}}
            />
            <Stack.Screen
                name="EvaluationDetail"
                component={lazy(() =>
                    import("@/features/evaluation/screens/EvaluationDetail.tsx").then(m => ({
                        default: m.EvaluationDetail,
                    })),
                )}
                options={{title: "学生评价细节"}}
            />
            <Stack.Screen
                name="EvaluationComment"
                component={lazy(() =>
                    import("@/features/evaluation/screens/EvaluationComment.tsx").then(m => ({
                        default: m.EvaluationComment,
                    })),
                )}
                options={{title: "填写评语"}}
            />
            <Stack.Screen
                name="EvaluationTemplate"
                component={lazy(() =>
                    import("@/features/evaluation/screens/EvaluationTemplate.tsx").then(m => ({
                        default: m.EvaluationTemplate,
                    })),
                )}
                options={{title: "评价模板"}}
            />

            <Stack.Screen
                name="TestPage"
                component={lazy(() => import("@/features/TestPage.tsx").then(m => ({default: m.TestPage})))}
                options={{title: "测试页"}}
            />
            <Stack.Screen
                name="FullCourseScreen"
                component={lazy(() =>
                    import("@/features/fullClassCourse/screens/FullCourseScreen.tsx").then(m => ({
                        default: m.FullCourseScreen,
                    })),
                )}
                options={{title: "全校实时课表"}}
            />

            <Stack.Screen
                name="PositionListScreen"
                component={lazy(() =>
                    import("@/screens/tool/other/mapNavigation/BuildingListScreen.tsx").then(m => ({
                        default: m.BuildingListScreen,
                    })),
                )}
                options={{title: "地图导航"}}
            />
            <Stack.Screen
                name="WidgetPreviewScreen"
                component={lazy(() =>
                    import("@/screens/tool/other/widgetPreview/WidgetPreviewScreen.tsx").then(m => ({
                        default: m.WidgetPreviewScreen,
                    })),
                )}
                options={{title: "小部件预览"}}
            />
            <Stack.Screen
                name="EduRechargeScreen"
                component={lazy(() => import("@/screens/WebViewScreen.tsx").then(m => ({default: m.default})))}
                options={{title: "校园网充值"}}
            />
            <Stack.Screen
                name="TeachBuildingListScreen"
                component={lazy(() =>
                    import("@/screens/tool/other/TeachingBuildingMap/TeachBuildingListScreen.tsx").then(m => ({
                        default: m.TeachBuildingListScreen,
                    })),
                )}
                options={{title: "教学楼平面图"}}
            />
            <Stack.Screen
                name="FloorListScreen"
                component={lazy(() =>
                    import("@/screens/tool/other/TeachingBuildingMap/FloorlistScreen.tsx").then(m => ({
                        default: m.FloorlistScreen,
                    })),
                )}
                options={{title: "楼层列表"}}
            />
            <Stack.Screen
                name="FloorMapScreen"
                component={lazy(() =>
                    import("@/screens/tool/other/TeachingBuildingMap/FloorMapScreen.tsx").then(m => ({
                        default: m.FloorMapScreen,
                    })),
                )}
                options={{title: "楼层平面图"}}
            />
            <Stack.Screen
                name="ExportScheduleScreen"
                component={lazy(() =>
                    import("@/screens/tool/jw/infoQuery/courseSchedule/ExportScheduleScreen.tsx").then(m => ({
                        default: m.ExportScheduleScreen,
                    })),
                )}
                options={{title: "导出课表"}}
            />
        </Stack.Navigator>
    );
}
