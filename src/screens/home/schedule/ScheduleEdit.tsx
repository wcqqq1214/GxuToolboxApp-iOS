import Flex from "@/components/un-ui/Flex";
import {UnPressable} from "@/components/un-ui";
import {ScrollView, StyleSheet, ToastAndroid, View} from "react-native";
import {BottomSheet, Divider, Input, Text, useTheme} from "@rneui/themed";
import {UnTermSelector} from "@/components/un-ui/UnTermSelector.tsx";
import React, {useEffect, useState} from "react";
import {CourseScheduleData} from "@/js/jw/course.ts";
import {usePagerView} from "react-native-pager-view";
import {UnSlider} from "@/components/un-ui/UnSlider.tsx";
import {IActivity} from "@/type/app/activity.ts";
import {Icon} from "@/components/un-ui/Icon.tsx";
import {Color} from "@/shared/color.ts";
import {NumberInput} from "@/components/un-ui/NumberInput.tsx";
import {Picker} from "@react-native-picker/picker";
import {ColorPicker} from "@/components/un-ui/ColorPicker.tsx";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {TimeScheduleView} from "@/components/tool/infoQuery/courseSchedule/TimeScheduleView.tsx";
import {ActivityItem} from "@/components/app/activity/ActivityItem.tsx";
import {ActivityDetail} from "@/components/app/activity/ActivityDetail.tsx";
import {TimeScheduleItemData} from "@/features/courseSchedule/type/schedule.ts";

export function ScheduleEdit() {
    const {store} = useUserConfig();
    const {theme} = useTheme();
    const pageView = usePagerView({pagesAmount: 20});

    const [year, setYear] = useState(store(s => s.jw.year));
    const [term, setTerm] = useState(store(s => s.jw.term));

    // 用户数据中的Index
    const [activityListIndex, setActivityListIndex] = useState(-1);
    const [activityList, setActivityList] = useState<IActivity[]>([]);

    function addActivity() {
        const color = CourseScheduleData.randomColor[Math.floor(Math.random() * CourseScheduleData.randomColor.length)];
        activityList.unshift({
            color,
            name: "新活动",
            timeSpan: [1, 2],
            weekSpan: [pageView.activePage + 1, pageView.activePage + 1],
            desc: "活动描述",
            weekday: 0,
        });
        setActivityList([...activityList]);
        save();
    }

    function editActivity(item: IActivity, index: number) {
        setEditModalOpen(true);
        setSelectedActivity(item);
        setSelectedIndex(index);
    }

    function deleteActivity(index: number) {
        activityList.splice(index, 1);
        setActivityList([...activityList]);
    }

    const [editModalOpen, setEditModalOpen] = useState(false);
    const [selectedIndex, setSelectedIndex] = useState(0);
    const [selectedActivity, setSelectedActivity] = useState<IActivity>();
    function closeEditModal() {
        activityList[selectedIndex] = selectedActivity!;
        setActivityList([...activityList]);
        setEditModalOpen(false);
        save();
    }

    function save() {
        const s = store.getState();
        const newData = [...s.activity.data];
        if (activityList.length === 0 && activityListIndex > -1) {
            // 日程为空就删除
            newData.splice(activityListIndex, 1);
            setActivityListIndex(-1);
        } else if (activityListIndex > -1) {
            // 替换
            newData[activityListIndex] = { ...newData[activityListIndex], list: activityList };
        } else {
            // 不存在就新建
            newData.push({
                year,
                term,
                list: activityList,
            });
            setActivityListIndex(newData.length - 1);
        }
        store.getState().update("activity", { ...s.activity, data: newData });
        ToastAndroid.show("保存日程成功", ToastAndroid.SHORT);
    }

    function updateSelectedActivity() {
        setSelectedActivity({...selectedActivity!});
    }

    async function init() {
        const activityData = store.getState().activity.data;
        const activityDataIndex = activityData.findIndex(item => item.year === year && item.term === term);
        if (activityDataIndex > -1) {
            setActivityList(activityData[activityDataIndex].list);
            setActivityListIndex(activityDataIndex);
        } else {
            setActivityList([]);
        }
    }

    useEffect(() => {
        init();
    }, [year, term]);

    const style = StyleSheet.create({
        activityListItem: {
            paddingHorizontal: "3%",
            paddingVertical: 20,
            borderRadius: 8,
            borderWidth: 2,
            borderColor: Color.mix(theme.colors.primary, theme.colors.white, 0.2).rgbaString,
        },
        activityListItemText: {
            fontSize: 14,
            fontWeight: "bold",
        },
        bottomSheetContainer: {
            backgroundColor: theme.colors.background,
            borderTopLeftRadius: 8,
            borderTopRightRadius: 8,
            borderColor: Color.mix(theme.colors.primary, theme.colors.background, 0.8).rgbaString,
            borderWidth: 1,
            padding: "2.5%",
        },
    });

    const [itemDetailShow, setItemDetailShow] = useState(false);
    const [itemDetail, setItemDetail] = useState<IActivity>();

    return (
        <ScrollView contentContainerStyle={{padding: "5%"}}>
            <Flex gap={10} direction="column" align="flex-start">
                <Flex gap={10}>
                    <Text>学期</Text>
                    <View style={{flex: 1}}>
                        <UnTermSelector
                            disableSelectAll
                            year={year}
                            term={term}
                            onChange={(year, term) => {
                                setYear(+year);
                                setTerm(term);
                            }}
                        />
                    </View>
                </Flex>
                <Divider />
                <Text h4>日程表预览</Text>
                <Flex style={{padding: 10}}>
                    <UnSlider
                        step={1}
                        minimumValue={1}
                        maximumValue={20}
                        allowTouchTrack
                        value={pageView.activePage + 1}
                        onValueChange={v => pageView.setPage(v - 1)}
                    />
                </Flex>
                <TimeScheduleView
                    pageView={pageView}
                    scheduleItems={[
                        {
                            data: activityList,
                            isItemShow: (item, day, week) =>
                                item.weekday === day.weekday() && week >= item.weekSpan[0] && week <= item.weekSpan[1],
                            itemRender: item => (
                                <ActivityItem
                                    item={item}
                                    onPress={() => {
                                        setItemDetailShow(true);
                                        setItemDetail(item);
                                    }}
                                />
                            ),
                        } as TimeScheduleItemData<IActivity>,
                    ]}
                />
                <Divider />
                <Flex justify="space-between">
                    <Text h4>日程列表</Text>
                    <Flex gap={5} justify="flex-end">
                        <UnPressable onPress={addActivity} style={{padding: 5}}>
                            <Icon name="plus" size={24} />
                        </UnPressable>
                        <UnPressable onPress={save} style={{padding: 5}}>
                            <Icon name="content-save" size={24} color={theme.colors.primary} />
                        </UnPressable>
                    </Flex>
                </Flex>
                <Flex justify="center" direction="column" gap={10}>
                    {activityList.length > 0 ? ( // 日程列表渲染
                        activityList.map((activity, index) => (
                            <Flex
                                key={index}
                                style={[
                                    {
                                        backgroundColor: Color(activity.color ?? theme.colors.primary).setAlpha(0.1)
                                            .rgbaString,
                                    },
                                    style.activityListItem,
                                ]}>
                                <Flex gap={5}>
                                    <Text
                                        style={[
                                            {
                                                color: Color.mix(
                                                    activity.color ?? theme.colors.primary,
                                                    theme.colors.black,
                                                    0.5,
                                                ).rgbaString,
                                            },
                                            style.activityListItemText,
                                        ]}>
                                        {activity.name}
                                    </Text>
                                    <Text
                                        style={{
                                            color: Color.mix(
                                                activity.color ?? theme.colors.primary,
                                                theme.colors.grey2,
                                                0.5,
                                            ).rgbaString,
                                        }}>
                                        {activity.weekSpan[0] === activity.weekSpan[1]
                                            ? `仅第${activity.weekSpan[0]}周`
                                            : `第${activity.weekSpan.join("至")}周`}
                                        &nbsp;|&nbsp;
                                        {`第${activity.timeSpan.join("至")}节`}
                                    </Text>
                                </Flex>
                                <Flex gap={5} justify="flex-end">
                                    <UnPressable
                                        onPress={() => editActivity(activity, index)}
                                        style={{padding: 5}}>
                                        <Icon name="edit" size={22} />
                                    </UnPressable>
                                    <UnPressable
                                        onPress={() => deleteActivity(index)}
                                        style={{padding: 5}}>
                                        <Icon name="delete" color={theme.colors.error} size={22} />
                                    </UnPressable>
                                </Flex>
                            </Flex>
                        ))
                    ) : (
                        <Text style={{fontSize: 16}}>
                            当前学期没有日程，点击上方
                            <Icon name="plus" size={18} />
                            添加日程
                        </Text>
                    )}
                </Flex>
            </Flex>
            {/* 日程编辑 */}
            <BottomSheet isVisible={editModalOpen} onBackdropPress={() => closeEditModal()}>
                <Flex direction="column" align="flex-start" style={style.bottomSheetContainer} gap={10}>
                    <Text>活动名称</Text>
                    <Input
                        value={selectedActivity?.name}
                        onChangeText={v => {
                            selectedActivity!.name = v;
                            updateSelectedActivity();
                        }}
                    />
                    <Flex justify="space-between">
                        <Text>节次长度（1-13）</Text>
                        <Flex gap={10} justify="flex-end">
                            <NumberInput
                                min={1}
                                max={selectedActivity?.timeSpan[1]}
                                value={selectedActivity?.timeSpan[0] ?? 1}
                                onChange={v => {
                                    selectedActivity!.timeSpan[0] = v;
                                    updateSelectedActivity();
                                }}
                            />
                            <Text>至</Text>
                            <NumberInput
                                min={selectedActivity?.timeSpan[0]}
                                max={13}
                                value={selectedActivity?.timeSpan[1] ?? 1}
                                onChange={v => {
                                    selectedActivity!.timeSpan[1] = v;
                                    updateSelectedActivity();
                                }}
                            />
                        </Flex>
                    </Flex>
                    <Flex justify="space-between">
                        <Text>周跨度（1-20）</Text>
                        <Flex gap={10} justify="flex-end">
                            <NumberInput
                                min={1}
                                max={selectedActivity?.weekSpan[1]}
                                value={selectedActivity?.weekSpan[0] ?? pageView.activePage + 1}
                                onChange={v => {
                                    selectedActivity!.weekSpan[0] = v;
                                    updateSelectedActivity();
                                }}
                            />
                            <Text>至</Text>
                            <NumberInput
                                min={selectedActivity?.weekSpan[0]}
                                max={20}
                                value={selectedActivity?.weekSpan[1] ?? pageView.activePage + 1}
                                onChange={v => {
                                    selectedActivity!.weekSpan[1] = v;
                                    updateSelectedActivity();
                                }}
                            />
                        </Flex>
                    </Flex>
                    <Flex>
                        <Text>所在星期</Text>
                        <Flex justify="flex-end">
                            <Picker<number>
                                onValueChange={v => {
                                    selectedActivity!.weekday = v;
                                    updateSelectedActivity();
                                }}
                                selectedValue={selectedActivity?.weekday ?? 0}
                                style={{width: "50%"}}>
                                {CourseScheduleData.weekdayList.slice(0, 6).map((text, index) => (
                                    <Picker.Item key={index} label={"星期" + text} value={index + 1} />
                                ))}
                                <Picker.Item label="星期日" value={0} />
                            </Picker>
                        </Flex>
                    </Flex>
                    <Flex>
                        <Text>颜色</Text>
                        <Flex justify="flex-end">
                            <ColorPicker
                                color={selectedActivity?.color ?? theme.colors.primary}
                                onColorChange={v => {
                                    selectedActivity!.color = v;
                                    updateSelectedActivity();
                                }}
                            />
                        </Flex>
                    </Flex>
                    <Text>活动描述</Text>
                    <Input
                        multiline
                        textAlignVertical="top"
                        style={{height: 200}}
                        value={selectedActivity?.desc}
                        onChangeText={v => {
                            selectedActivity!.desc = v;
                            updateSelectedActivity();
                        }}
                    />
                </Flex>
            </BottomSheet>
            <BottomSheet isVisible={itemDetailShow} onBackdropPress={() => setItemDetailShow(false)}>
                <View
                    style={{
                        backgroundColor: theme.colors.background,
                        borderTopLeftRadius: 8,
                        borderTopRightRadius: 8,
                        borderColor: Color.mix(theme.colors.primary, theme.colors.background, 0.8).rgbaString,
                        borderWidth: 1,
                        padding: "2.5%",
                    }}>
                    <ActivityDetail activity={itemDetail} />,
                </View>
            </BottomSheet>
        </ScrollView>
    );
}
