import React from "react";
import {StyleProp, View, ViewStyle} from "react-native";
import {Text, useTheme} from "@rneui/themed";
import {UnPressable} from "@/components/un-ui";
import Flex from "@/components/un-ui/Flex.tsx";
import {UnSlider} from "@/components/un-ui/UnSlider.tsx";
import {SchoolYearValue} from "@/type/global.ts";
import {usePagerView} from "react-native-pager-view";
import {UnTermSelector} from "@/components/un-ui/UnTermSelector.tsx";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {useCourseData} from "@/hooks/useCourseData.ts";
import {useBlocksColor} from "@/features/courseSchedule/hooks/useBlocksColor.ts";
import {ColorPalettes, PaletteName} from "@/features/courseSchedule/utils/colorPalette.ts";
import {Color} from "@/shared/color.ts";

interface Props {
    containerStyle?: StyleProp<ViewStyle>;
    pageViewRest: Omit<ReturnType<typeof usePagerView>, "AnimatedPagerView" | "ref">;
}

export function SettingSheet(props: Props) {
    const {theme} = useTheme();

    const {store: ucStore} = useUserConfig();
    const year = +ucStore(s => s.jw.year);
    const term = ucStore(s => s.jw.term);
    const {store} = useCourseData();
    const timeSpanHeight = store(s => s.theme.timeSpanHeight);
    const courseInfoVisible = store(s => s.courseInfoVisible);

    const infoVisibleOptions: Record<string, string> = {
        name: "课程名称",
        position: "上课地点",
        teacher: "教师名称",
    };
    const changeCourseInfoVisible = (key: string, v: boolean) => {
        const newCourseInfoVisible = {...courseInfoVisible};
        newCourseInfoVisible[key] = v;
        store.getState().update("courseInfoVisible", newCourseInfoVisible);
    };

    const {getColor, setCustomColor, paletteName} = useBlocksColor();

    return (
        <View style={props.containerStyle}>
            {/* ── 课表周数 ── */}
            <Flex justify="space-between" style={{marginBottom: 4}}>
                <Text style={{fontSize: 13, color: theme.colors.grey3}}>当前周数</Text>
                <Text style={{fontSize: 13, color: theme.colors.grey1}}>第 {props.pageViewRest.activePage + 1} 周</Text>
            </Flex>
            <View style={{marginBottom: 16}}>
                <UnSlider
                    step={1}
                    minimumValue={1}
                    maximumValue={20}
                    allowTouchTrack
                    value={props.pageViewRest.activePage + 1}
                    onValueChange={v => props.pageViewRest.setPage(v - 1)}
                />
            </View>

            {/* ── 显示内容 ── */}
            <Text style={{fontSize: 13, color: theme.colors.grey3, marginBottom: 4}}>显示内容</Text>
            <View style={{flexDirection: "row", flexWrap: "wrap", gap: 6, marginBottom: 16}}>
                {(Object.keys(infoVisibleOptions) as (keyof typeof infoVisibleOptions)[]).map(key => {
                    const active = courseInfoVisible[key];
                    return (
                        <UnPressable
                            key={key}
                            onPress={function () {
                                return changeCourseInfoVisible(key, !active);
                            }}
                            style={{
                                paddingVertical: 6,
                                paddingHorizontal: 14,
                                borderRadius: 16,
                                borderWidth: 1,
                                borderColor: active ? theme.colors.primary : theme.colors.greyOutline,
                                backgroundColor: active
                                    ? Color(theme.colors.primary).setAlpha(0.1).rgbaString
                                    : "transparent",
                            }}>
                            <Text
                                style={{
                                    fontSize: 13,
                                    color: active ? theme.colors.primary : theme.colors.grey2,
                                }}>
                                {infoVisibleOptions[key]}
                            </Text>
                        </UnPressable>
                    );
                })}
            </View>

            {/* ── 课程元素高度 ── */}
            <Flex justify="space-between" style={{marginBottom: 4}}>
                <Text style={{fontSize: 13, color: theme.colors.grey3}}>课程元素高度</Text>
                <Text style={{fontSize: 13, color: theme.colors.grey1}}>{timeSpanHeight}</Text>
            </Flex>
            <View style={{marginBottom: 16}}>
                <UnSlider
                    step={1}
                    minimumValue={5}
                    maximumValue={100}
                    allowTouchTrack
                    value={timeSpanHeight}
                    onValueChange={v => {
                        store.getState().update("theme", {...store.getState().theme, timeSpanHeight: v});
                    }}
                />
            </View>

            {/* ── 学期设置 ── */}
            <Text style={{fontSize: 13, color: theme.colors.grey3, marginBottom: 4}}>学期设置</Text>
            <View style={{marginBottom: 16}}>
                <Flex gap={10} style={{marginBottom: 8}}>
                    <Text>学期</Text>
                    <View style={{flex: 1}}>
                        <UnTermSelector
                            disableSelectAll
                            skipAndroidStatusBar
                            year={year}
                            term={term}
                            onChange={(nextYear, nextTerm) => {
                                const s = ucStore.getState();
                                ucStore.getState().update("jw", {
                                    ...s.jw,
                                    year: String(nextYear) as SchoolYearValue,
                                    term: nextTerm,
                                });
                            }}
                        />
                    </View>
                </Flex>
            </View>

            {/* ── 配色风格 ── */}
            <Text style={{fontSize: 13, color: theme.colors.grey3, marginBottom: 4}}>配色风格</Text>
            <View style={{flexDirection: "row", flexWrap: "wrap", gap: 10}}>
                {(Object.keys(ColorPalettes) as PaletteName[]).map(name => {
                    const isActive = name === paletteName;
                    const label: Record<PaletteName, string> = {
                        default: "经典",
                        macaron: "马卡龙",
                        morandi: "莫兰迪",
                        vivid: "鲜明",
                    };
                    return (
                        <UnPressable
                            key={name}
                            onPress={function () {
                                store.getState().update("theme", {...store.getState().theme, palette: name});
                            }}
                            style={{
                                flex: 1,
                                minWidth: "45%",
                                padding: 10,
                                borderRadius: 8,
                                borderWidth: isActive ? 2 : 1,
                                borderColor: isActive ? theme.colors.primary : theme.colors.greyOutline,
                                backgroundColor: isActive
                                    ? Color(theme.colors.primary).setAlpha(0.08).rgbaString
                                    : "transparent",
                            }}>
                            <Text
                                style={{
                                    fontWeight: isActive ? "bold" : "normal",
                                    marginBottom: 6,
                                    color: isActive ? theme.colors.primary : theme.colors.grey0,
                                }}>
                                {label[name]}
                            </Text>
                            <View style={{flexDirection: "row", gap: 4, flexWrap: "wrap"}}>
                                {ColorPalettes[name].slice(0, 20).map((c, i) => (
                                    <View
                                        key={i}
                                        style={{
                                            width: 16,
                                            height: 16,
                                            borderRadius: 8,
                                            backgroundColor: c,
                                        }}
                                    />
                                ))}
                            </View>
                        </UnPressable>
                    );
                })}
            </View>
        </View>
    );
}
