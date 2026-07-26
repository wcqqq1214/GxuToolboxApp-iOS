import {Button, Switch} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";
import packageJson from "@/../package.json";
import moment from "moment/moment";
import {ColorPicker} from "@/components/un-ui/ColorPicker.tsx";
import {launchImageLibrary} from "react-native-image-picker";
import {UnSlider} from "@/components/un-ui/UnSlider.tsx";
import {UnListSection, UnSectionList} from "@/components/un-ui/UnSectionList.tsx";
import {ToastAndroid} from "react-native";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {useCourseData} from "@/hooks/useCourseData.ts";
import {Color} from "@/shared/color.ts";
import {getCurrentOTAVersionCode} from "@/core/ota.ts";

export function SettingIndex() {
    const {store: ucStore} = useUserConfig();
    const {store} = useCourseData();

    function selectBg() {
        launchImageLibrary({
            mediaType: "photo",
        }).then(res => {
            if (!res.didCancel && res.assets && res.assets.length > 0) {
                const s = ucStore.getState();
                ucStore.getState().update("theme", {...s.theme, bgUrl: res.assets[0].uri ?? ""});
                ToastAndroid.show("设置成功", ToastAndroid.SHORT);
            }
        });
    }

    const settingList: UnListSection[] = [
        {
            title: "账号",
            data: [
                {
                    label: "查看个人信息",
                    type: "navigation",
                    value: "personalInfo",
                },
                {
                    label: "教务账号设置",
                    type: "navigation",
                    value: "jwAccount",
                },
                {
                    label: "统一认证账号设置",
                    type: "navigation",
                    value: "authAccount",
                },
                {
                    label: "考勤系统账号设置",
                    type: "navigation",
                    value: "attendanceSystemAccount",
                },
                // {
                //     label: "偏好设置",
                //     type: "navigation",
                //     value: "userPreferenceSetting",
                // },
            ],
        },
        {
            title: "主题",
            data: [
                {
                    label: "主题色",
                    type: "any",
                    value: (
                        <ColorPicker
                            color={ucStore(s => s.theme.primaryColor)}
                            onColorChange={v => {
                                const s = ucStore.getState();
                                ucStore.getState().update("theme", {
                                    ...s.theme,
                                    primaryColor: v,
                                    ripple: {color: Color(v).setAlpha(0.5).rgbaString},
                                });
                            }}
                        />
                    ),
                },
                {
                    label: "课程颜色",
                    type: "any",
                    value: (
                        <Flex gap={10} inline>
                            <Button
                                onPress={() => {
                                    store.getState().update("theme", {...store.getState().theme, courseColor: {}});
                                    ToastAndroid.show("清空成功", ToastAndroid.SHORT);
                                }}
                                size="sm">
                                清空课程颜色缓存
                            </Button>
                        </Flex>
                    ),
                },
                {
                    label: "背景图",
                    type: "any",
                    value: (
                        <Flex gap={10} inline>
                            <Button
                                onPress={() => {
                                    const s = ucStore.getState();
                                    ucStore.getState().update("theme", {...s.theme, bgUrl: ""});
                                    ToastAndroid.show("清空成功", ToastAndroid.SHORT);
                                }}
                                size="sm">
                                重置背景
                            </Button>
                            <Button onPress={selectBg} size="sm">
                                选择图片
                            </Button>
                        </Flex>
                    ),
                },
                {
                    label: "背景蒙版相对透明度",
                    type: "blockAny",
                    value: (
                        <UnSlider
                            step={1}
                            minimumValue={0}
                            maximumValue={130}
                            value={ucStore(s => s.theme.bgOpacity)}
                            onValueChange={v => {
                                const s = ucStore.getState();
                                ucStore.getState().update("theme", {...s.theme, bgOpacity: v});
                            }}
                        />
                    ),
                },
            ],
        },
        {
            title: "软件",
            data: [
                {
                    label: "意见反馈",
                    type: "navigation",
                    value: "feedback",
                },
                {
                    label: "开发模式",
                    type: "any",
                    value: (
                        <Switch
                            value={ucStore(s => s.devMode)}
                            onValueChange={v => ucStore.getState().update("devMode", v)}
                        />
                    ),
                },
                {
                    label: "代码版本号",
                    type: "text",
                    value: packageJson.version,
                },
                {
                    label: "OTA 版本号",
                    type: "text",
                    value: (() => {
                        const code = getCurrentOTAVersionCode();
                        return code > 0 ? String(code) : "无";
                    })(),
                },
                {
                    label: "源代码",
                    type: "link",
                    value: "GitLab",
                    url: "https://gitlab.unde.site/gxutool/gxu_tool_app",
                },
                {
                    label: "软件文档",
                    type: "link",
                    value: "Docs",
                    url: "https://tooldoc.gxutech.xyz/",
                },
                {
                    label: "公测群",
                    type: "link",
                    value: "580048805",
                    url: "https://qm.qq.com/q/tVlQHwhwXu",
                },
                {
                    label: "软件信息",
                    type: "text",
                    value: `CopyRight © 2025-${moment().year()} \n寰辰 <UNDERLR@foxmail.com>\n 蹑景 <nieying58@gmail.com>`,
                },
            ],
        },
    ];

    return <UnSectionList sections={settingList} contentContainerStyle={{padding: "5%"}} />;
}
