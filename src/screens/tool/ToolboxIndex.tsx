import {PressableAndroidRippleConfig, ScrollView, StyleSheet, View} from "react-native";
import {Text, useTheme} from "@rneui/themed";
import {Color} from "@/shared/color.ts";
import {useNavigation} from "@react-navigation/native";
import {Icon} from "@/components/un-ui/Icon.tsx";
import React from "react";
import {Flex, UnCard, UnPressable} from "@/components/un-ui";
import {useWebView} from "@/hooks/app.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";

interface settingSection {
    title: string;
    data: ToolboxItem[];
}

type ToolboxItem =
    | {
          label: string;
          icon?: React.ReactNode;
          type?: "navigation";
          navigation: string;
      }
    | {
          label: string;
          icon?: React.ReactNode;
          type?: "callback";
          onClick: () => void;
      };

const iconSize = 25;

export function ToolboxIndex() {
    const navigation = useNavigation();
    const {theme} = useTheme();
    const {openInWeb} = useWebView();
    const {store} = useUserConfig();
    const bgOpacity = store(s => s.theme.bgOpacity);

    const toolList = [
        {
            title: "信息查询",
            data: [
                {
                    label: "课表",
                    icon: <Icon name="calendar-month" size={iconSize} />,
                    type: "navigation",
                    navigation: "courseScheduleQuery",
                },
                {
                    label: "班级课表",
                    icon: <Icon name="calendar-month-outline" size={iconSize} />,
                    type: "navigation",
                    navigation: "classCourseSchedule",
                },
                {
                    label: "导出课表",
                    icon: <Icon name="file-export-outline" size={iconSize} />,
                    type: "navigation",
                    navigation: "ExportScheduleScreen",
                },
                {
                    label: "考试考场",
                    icon: <Icon name="information-box-outline" size={iconSize} />,
                    type: "navigation",
                    navigation: "examInfo",
                },
                {
                    label: "考试成绩",
                    icon: <Icon name="chart-box" size={iconSize} />,
                    type: "navigation",
                    navigation: "examScore",
                },
                {
                    label: "考勤信息",
                    icon: <Icon name="clock" size={iconSize} />,
                    type: "navigation",
                    navigation: "AttendanceInfoQueryScreen",
                },
                {
                    label: "选课课程列表",
                    icon: <Icon name="list-box" size={iconSize} />,
                    type: "navigation",
                    navigation: "courseSelectionList",
                },
                {
                    label: "校选课查漏",
                    icon: <Icon name="archive-check-outline" size={iconSize} />,
                    type: "navigation",
                    navigation: "ElectiveStrategy",
                },
                {
                    label: "教师信息查询",
                    icon: <Icon type="Ionicons" name="user" size={iconSize} />,
                    type: "navigation",
                    navigation: "TeacherQueryInfoScreen",
                },
                // {
                //     label: "自主选课",
                //     icon: <Icon name="barschart" size={iconSize} />,
                //     navigation: "SelfSelectedCourse",
                // },
            ],
        },
        {
            title: "实践课",
            data: [
                {
                    label: "物理实验课",
                    icon: <Icon name="flask" size={iconSize} />,
                    type: "navigation",
                    navigation: "phyExpScreen",
                },
                {
                    label: "金工实训",
                    icon: <Icon name="tools" size={iconSize} />,
                    type: "navigation",
                    navigation: "engTrainingScheduleScreen",
                },
            ],
        },
        {
            title: "通知",
            data: [
                {
                    label: "调课信息",
                    icon: <Icon name="clock-star-four-points-outline" size={iconSize} />,
                    type: "navigation",
                    navigation: "reschedulingNews",
                },
                {
                    label: "调休信息",
                    icon: <Icon name="calendar-clock" size={iconSize} />,
                    type: "navigation",
                    navigation: "timeShiftScreen",
                },
                {
                    label: "法定节假日",
                    icon: <Icon name="bed" size={iconSize} />,
                    type: "navigation",
                    navigation: "HolidayScreen",
                },
                {
                    label: "学校文件",
                    icon: <Icon name={"file-document"} size={iconSize} />,
                    type: "navigation",
                    navigation: "MainScreen",
                },
            ],
        },
        {
            title: "教学评价",
            data: [
                {
                    label: "期末学生评价",
                    icon: <Icon name="invoice-text-edit" size={iconSize} />,
                    type: "navigation",
                    navigation: "EvaluationOverview",
                },
            ],
        },
        {
            title: "其他",
            data: [
                {
                    label: "地图导航",
                    icon: <Icon name="map" size={iconSize} />,
                    type: "navigation",
                    navigation: "PositionListScreen",
                },
                // {
                //     label: "测试页",
                //     icon: <Icon name="map" size={iconSize} />,
                //     type: "navigation",
                //     navigation: "TestPage",
                // },
                {
                    label: "全校实时课表",
                    icon: <Icon name="calendar-search" size={iconSize} />,
                    type: "navigation",
                    navigation: "FullCourseScreen",
                },
                // {
                //     label: "小部件预览",
                //     icon: <Icon name="widgets" size={iconSize} />,
                //     type: "navigation",
                //     navigation: "WidgetPreviewScreen",
                // },
                // {
                //     label: "校园网充值",
                //     icon: <Icon name="wifi" size={iconSize} />,
                //     type: "callback",
                //     onClick: () => {
                //         openInWeb("校园网充值", {
                //             uri: "https://xywjf.gxu.edu.cn/WebPay/toRecharge",
                //         });
                //     },
                // },
                {
                    label: "教学楼平面图",
                    icon: <Icon name="city-variant" size={iconSize} />,
                    type: "navigation",
                    navigation: "TeachBuildingListScreen",
                },
            ],
        },
    ] as settingSection[];
    const data = {
        style: {
            settingItemRipple: {
                color: theme.colors.grey4,
            } as PressableAndroidRippleConfig,
        },
    };

    const style = StyleSheet.create({
        settingContainer: {
            padding: "5%",
        },
        settingSectionContainer: {
            paddingHorizontal: "3%",
            paddingTop: "2%",
            paddingBottom: "5%",
            borderRadius: 16,
            backgroundColor: Color(theme.mode === "light" ? theme.colors.background : theme.colors.grey5).setAlpha(
                0.1 + ((theme.mode === "light" ? 0.7 : 0.1) * bgOpacity) / 100,
            ).rgbaString,
            marginBottom: 10,
        },
        toolListContainer: {
            flexWrap: "wrap",
            width: "100%",
            paddingTop: 10,
        },
        settingItem: {
            width: "33%",
            borderRadius: 8,
            paddingVertical: 10,
        },
        toolIcon: {
            marginVertical: 10,
        },
        toolLabel: {
            fontSize: 14,
            textAlign: "center",
        },
    });

    function itemClick(item: ToolboxItem) {
        switch (item.type) {
            case "navigation":
                navigation.navigate(item.navigation);
                return;
            case "callback":
                item.onClick();
        }
    }

    return (
        <ScrollView contentContainerStyle={style.settingContainer}>
            {toolList.map(section => (
                <UnCard
                    titleColor={theme.colors.black}
                    style={style.settingSectionContainer}
                    title={section.title}
                    key={`tool-${section.title}`}>
                    <Flex style={style.toolListContainer}>
                        {section.data.map(tool => (
                            <UnPressable
                                key={`tool-${section.title}-${tool.label}`}
                                style={style.settingItem}
                                onPress={function () {
                                    return itemClick(tool);
                                }}>
                                <Flex direction="column" inline>
                                    <View style={style.toolIcon}>{tool.icon}</View>
                                    <Text style={style.toolLabel}>{tool.label}</Text>
                                </Flex>
                            </UnPressable>
                        ))}
                    </Flex>
                </UnCard>
            ))}
        </ScrollView>
    );
}
