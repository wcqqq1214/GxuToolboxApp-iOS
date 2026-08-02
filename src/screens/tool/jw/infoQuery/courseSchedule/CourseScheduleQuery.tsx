import {ActivityIndicator, Linking, ScrollView, StyleSheet, ToastAndroid, View} from "react-native";
import {useNavigation} from "@react-navigation/native";
import {Icon, UnJsonEditor, UnPressable, UnTable, UnTableCols, UnText} from "@/components/un-ui";
import Flex from "@/components/un-ui/Flex.tsx";
import {BottomSheet, Button, Card, Divider, Text, useTheme} from "@rneui/themed";
import React, {useCallback, useEffect, useMemo, useState} from "react";
import {SchoolTermValue} from "@/type/global.ts";
import {UnSlider} from "@/components/un-ui/UnSlider.tsx";
import {PracticalCourseList} from "@/features/courseSchedule/components/PracticalCourseList.tsx";
import {usePagerView} from "react-native-pager-view";
import Clipboard from "@react-native-clipboard/clipboard";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {TimeScheduleView} from "@/components/tool/infoQuery/courseSchedule/TimeScheduleView.tsx";
import {Color} from "@/shared/color.ts";
import {CourseDetail} from "@/features/courseSchedule/components/CourseDetail.tsx";
import {CourseClass} from "@/class/jw/course.ts";
import {ScheduleTableItem, TimeScheduleItemData} from "@/features/courseSchedule/type/schedule.ts";
import {useCourse} from "@/features/courseSchedule/hooks/detail/useCourse.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {usePractice} from "@/features/courseSchedule/hooks/detail/usePractice.ts";
import {usePhyExp} from "@/features/courseSchedule/hooks/detail/usePhyExp.ts";
import {ChooseTerm} from "@/components/tool/infoQuery/examInfo/ChooseTerm.tsx";
import {NewCourseItem} from "@/features/courseSchedule/components/NewCourseItem.tsx";
import {StackCourseItem} from "@/features/courseSchedule/components/StackCourseItem.tsx";
import {useConflictCourseStore} from "@/features/courseSchedule/stores/useConflictCourseStore.ts";
import {ConflictCourseSheet} from "@/features/courseSchedule/components/ConflictCourseList.tsx";
import moment from "moment/moment";

type SheetState =
    | {type: "closed"}
    | {type: "itemDetail"; item: ScheduleTableItem; day: moment.Moment}
    | {type: "courseConflict"; courses: CourseClass[]; day: moment.Moment};

export function CourseScheduleQuery() {
    const navigation = useNavigation();
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const devMode = store(s => s.devMode);

    const {store: conflictStore} = useConflictCourseStore();

    const [year, setYear] = useState(+store(s => s.jw.year));
    const [term, setTerm] = useState<SchoolTermValue>(store(s => s.jw.term));
    const pageView = usePagerView({pagesAmount: 20});

    const {items: courseItems = [], loading} = useCourse(year, term);
    const {items: practiceItems = [], refresh: refreshPractice} = usePractice(year, term);
    const {init: initPhyExp, patchItem, patchCourse} = usePhyExp();

    // 不绑定全局的startDay，根据year和term动态计算，以免造成混乱
    const startDay = useStartDay(year, term);

    useEffect(() => {
        initPhyExp();
    }, [year, term]);

    const tableData = useMemo(
        () => courseItems.filter((item, idx, arr) => arr.findIndex(i => i.title === item.title) === idx),
        [courseItems],
    );
    const style = StyleSheet.create({
        container: {
            padding: "3%",
        },
        coursePadding: {
            marginHorizontal: -12,
        },
        tableText: {
            color: theme.colors.black,
            margin: 5,
            textAlign: "center",
        },
    });

    async function qqLink(qq: string) {
        const url = `mqqapi://card/show_pslcard?src_type=internal&version=1&uin=${qq}&card_type=group&source=qrcode`;
        await Linking.openURL(url).catch(e => {
            console.error(e);
            ToastAndroid.show("无法直接跳转QQ，已将QQ群号复制至剪切板", ToastAndroid.SHORT);
            Clipboard.setString(qq);
        });
    }

    const cols: UnTableCols<ScheduleTableItem> = [
        {
            title: "课程名",
            width: 150,
            dataIndex: "title",
        },
        {
            title: "教师",
            width: 70,
            dataIndex: "teacher",
        },
        {
            title: "上课地点",
            width: 100,
            dataIndex: "location",
        },
        {
            title: "qq群",
            width: 150,
            dataIndex: "qq",
            render: qq =>
                qq?.trim() ? (
                    <UnPressable
                        onPress={function () {
                            return qqLink(qq);
                        }}>
                        <Text style={style.tableText}>{qq}</Text>
                    </UnPressable>
                ) : (
                    "-"
                ),
        },
    ];

    const [sheet, setSheet] = useState<SheetState>({type: "closed"});

    const onItemPress = useCallback(
        (item: ScheduleTableItem, day: moment.Moment) => setSheet({type: "itemDetail", item, day}),
        [],
    );

    return (
        <ScrollView>
            <View style={style.container}>
                <View style={{flex: 1, padding: "-1%"}}>
                    <ChooseTerm
                        onTermSelect={(Year, Term) => {
                            setYear(+Year);
                            setTerm(+Term);
                        }}
                        includeWholeLife={false}
                        includeWholeYear={false}
                    />
                </View>
                {loading && <ActivityIndicator size="large" />}
                <Divider />
                <Button
                    title="导出课表"
                    onPress={() => navigation.navigate("ExportScheduleScreen", {tab: "personal"})}
                    containerStyle={{marginVertical: 8}}
                />
                <Text h4>预览</Text>
                <Flex style={{padding: 10}} align="flex-start" direction="column" gap={10}>
                    <Text>课表周数</Text>
                    <UnSlider
                        step={1}
                        minimumValue={1}
                        maximumValue={20}
                        allowTouchTrack
                        value={pageView.activePage + 1}
                        onValueChange={v => pageView.setPage(v - 1)}
                    />
                </Flex>
                <View style={style.coursePadding}>
                    <TimeScheduleView
                        startDay={startDay}
                        pageView={pageView}
                        scheduleItems={[
                            {
                                data: courseItems,
                                isItemShow: (item: ScheduleTableItem, day: moment.Moment, week: number) => {
                                    return item.week === week && item.day === day.isoWeekday();
                                },
                                itemRender: (item, day) => (
                                    <NewCourseItem item={patchItem(item, day)} onPress={() => onItemPress(item, day)} />
                                ),
                                isItemStack: (a, b) => a.begin <= b.end && b.begin <= a.end,
                                stackRender: (items, day, _week, timeRange) => {
                                    const courses = items
                                        .map(i => patchCourse(new CourseClass(i.raw), day))
                                        .filter(Boolean);
                                    if (courses.length === 0) return null;
                                    const courseCodes = courses.map(c => c.transformed.courseCode + "_" + c.transformed.staffId).sort();
                                    const storedActive = conflictStore.getState().getActive(courseCodes);
                                    const activeCourse = storedActive ?? (courses[0] ? courses[0].transformed.courseCode + "_" + courses[0].transformed.staffId : "");
                                    return (
                                        <StackCourseItem
                                            course={courses}
                                            activeCourse={activeCourse}
                                            timeRange={timeRange}
                                            onPress={c => setSheet({type: "courseConflict", courses: c, day})}
                                        />
                                    );
                                },
                            } as TimeScheduleItemData,
                        ]}
                    />
                </View>
                {practiceItems && (
                    <>
                        <Card.Divider />
                        <PracticalCourseList courseList={practiceItems} />
                    </>
                )}
                {devMode && (
                    <Flex gap={8} direction="column">
                        <ScheduleDataDebugCard label="查看课程数据" data={courseItems} />
                        <ScheduleDataDebugCard label="查看实践课数据" data={practiceItems} />
                    </Flex>
                )}
                <Divider />
                <Text h4>课程列表</Text>
                <ScrollView horizontal style={{marginTop: 10}}>
                    <UnTable<ScheduleTableItem> data={tableData} cols={cols} />
                </ScrollView>
            </View>
            <BottomSheet isVisible={sheet.type !== "closed"} onBackdropPress={() => setSheet({type: "closed"})}>
                <View
                    style={{
                        backgroundColor: theme.colors.background,
                        borderTopLeftRadius: 8,
                        borderTopRightRadius: 8,
                        borderColor: Color.mix(theme.colors.primary, theme.colors.background, 0.8).rgbaString,
                        borderWidth: 1,
                        padding: "2.5%",
                    }}>
                    {sheet.type === "itemDetail" && sheet.item.raw && (
                        <CourseDetail course={new CourseClass(sheet.item.raw)} />
                    )}
                    {sheet.type === "courseConflict" && (
                        <ConflictCourseSheet
                            courses={sheet.courses}
                            onSelect={() => setSheet({type: "closed"})}
                            onPressActiveCourse={course => {
                                setSheet({
                                    type: "itemDetail",
                                    day: sheet.day,
                                    item: {
                                        id: course.transformed.courseCode,
                                        week: 0,
                                        day: 1 as ScheduleTableItem["day"],
                                        begin: 1 as ScheduleTableItem["begin"],
                                        end: 1 as ScheduleTableItem["begin"],
                                        title: course.transformed.courseName,
                                        location: course.transformed.venueName,
                                        teacher: course.transformed.name,
                                        raw: course,
                                    },
                                });
                            }}
                        />
                    )}
                </View>
            </BottomSheet>
        </ScrollView>
    );
}

function ScheduleDataDebugCard({label, data}: {label: string; data: any}) {
    const {theme} = useTheme();
    const [modalOpen, setModalOpen] = useState(false);

    const styles = StyleSheet.create({
        card: {
            padding: 6,
            borderRadius: 4,
            backgroundColor: Color(theme.colors.error).setAlpha(theme.mode === "light" ? 0.5 : 0.3).rgbaString,
        },
    });
    return (
        <Flex>
            <UnPressable onPress={() => setModalOpen(true)}>
                <Flex style={styles.card} justify="flex-start" gap={4}>
                    <Icon name="console" size={16} inline />
                    <UnText weight="bold" size={16}>
                        {label}
                    </UnText>
                </Flex>
            </UnPressable>
            <UnJsonEditor.Modal readOnly visible={modalOpen} onClose={() => setModalOpen(false)} value={data} />
        </Flex>
    );
}
