import React, {useCallback, useState} from "react";
import {ActivityIndicator, ScrollView, StyleSheet, View} from "react-native";
import {useNavigation} from "@react-navigation/native";
import {BottomSheet, Button, Card, Divider, Text, useTheme} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";
import {Schools} from "@/type/global.ts";
import {usePagerView} from "react-native-pager-view";
import {PracticalCourseList} from "@/features/courseSchedule/components/PracticalCourseList.tsx";
import {UnSlider} from "@/components/un-ui/UnSlider.tsx";
import {UnPicker} from "@/components/un-ui/UnPicker.tsx";
import {Picker} from "@react-native-picker/picker";
import {UnTermSelector} from "@/components/un-ui/UnTermSelector.tsx";
import {useSchoolTerm} from "@/hooks/jw.ts";
import {useWebView} from "@/hooks/app.ts";
import {TimeScheduleView} from "@/components/tool/infoQuery/courseSchedule/TimeScheduleView.tsx";
import {useFilter} from "@/features/classCourseSchedule/hooks/useFilter.ts";
import {useClassScheduleData} from "@/features/classCourseSchedule/hooks/useClassScheduleData.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import moment from "moment/moment";
import {NewCourseItem} from "@/features/courseSchedule/components/NewCourseItem.tsx";
import {ScheduleTableItem, TimeScheduleItemData} from "@/features/courseSchedule/type/schedule.ts";
import {CourseDetail} from "@/features/courseSchedule/components/CourseDetail.tsx";
import {CourseClass} from "@/class/jw/course.ts";
import {StackCourseItem} from "@/features/courseSchedule/components/StackCourseItem.tsx";
import {useConflictCourseStore} from "@/features/courseSchedule/stores/useConflictCourseStore.ts";
import {ConflictCourseSheet} from "@/features/courseSchedule/components/ConflictCourseList.tsx";
import {Color} from "@/shared/color.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {Icon, UnJsonEditor, UnPressable, UnText} from "@/components/un-ui";

type SheetState =
    | {type: "closed"}
    | {type: "itemDetail"; item: ScheduleTableItem; day: moment.Moment}
    | {type: "courseConflict"; courses: CourseClass[]; day: moment.Moment};

export function ClassCourseSchedule() {
    const navigation = useNavigation();
    const {openInJw} = useWebView();
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const devMode = store(s => s.devMode);

    const {store: conflictStore} = useConflictCourseStore();

    const {
        school,
        changeSchool,
        subject,
        grade,
        classId,
        setClassId,
        classList,
        subjectList,
        changeGrade,
        changeSubject,
    } = useFilter();

    const pageView = usePagerView({pagesAmount: 20});
    const {year, term, setBoth} = useSchoolTerm();
    const {list, index, fetchList, theorySchedule, practicalSchedule, loading, fetchSchedule, setIndex} =
        useClassScheduleData();

    const startDay = useStartDay(+year, term);

    const [sheet, setSheet] = useState<SheetState>({type: "closed"});

    const onItemPress = useCallback(
        (item: ScheduleTableItem, day: moment.Moment) => setSheet({type: "itemDetail", item, day}),
        [],
    );

    return (
        <ScrollView>
            <View style={style.container}>
                <Text h4>查询参数</Text>
                <Flex gap={10} direction="column" align="flex-start">
                    <Flex gap={10}>
                        <Text style={style.label}>学期</Text>
                        <View style={{flex: 1}}>
                            <UnTermSelector year={year} term={term} onChange={setBoth} disableSelectAll />
                        </View>
                    </Flex>
                    <Flex gap={10}>
                        <Text style={style.label}>学院</Text>
                        <View style={{flex: 1}}>
                            <UnPicker selectedValue={school} onValueChange={changeSchool}>
                                {[["", "全部"], ...Schools].map(value => {
                                    return <Picker.Item value={value[0]} label={value[1]} key={value[0]} />;
                                })}
                            </UnPicker>
                        </View>
                    </Flex>
                    <Flex gap={10}>
                        <Text style={style.label}>专业</Text>
                        <View style={{flex: 1}}>
                            <UnPicker selectedValue={subject} onValueChange={changeSubject}>
                                {[["", "全部"]].concat(subjectList ?? []).map(value => {
                                    return <Picker.Item value={value[0]} label={value[1]} key={value[0]} />;
                                })}
                            </UnPicker>
                        </View>
                    </Flex>
                    <Flex gap={10}>
                        <Text style={style.label}>年级</Text>
                        <View style={{flex: 1}}>
                            <UnPicker selectedValue={grade} onValueChange={changeGrade}>
                                {[["", "全部"], ...Array(25).fill(0)].map((v, index, ori) => {
                                    if (v === 0) {
                                        const optionV = 2003 + (ori.length - index);
                                        return <Picker.Item value={optionV} label={optionV + ""} key={optionV} />;
                                    } else {
                                        return <Picker.Item value={v[0]} label={v[1]} key={v[0]} />;
                                    }
                                })}
                            </UnPicker>
                        </View>
                    </Flex>
                    <Flex gap={10}>
                        <Text style={style.label}>班级</Text>
                        <View style={{flex: 1}}>
                            <UnPicker selectedValue={classId} onValueChange={setClassId}>
                                {[["", "全部"]].concat(classList ?? []).map(value => {
                                    return <Picker.Item value={value[0]} label={value[1]} key={value[0]} />;
                                })}
                            </UnPicker>
                        </View>
                    </Flex>
                    <Flex gap={10}>
                        <Button
                            containerStyle={{flex: 1}}
                            onPress={() => fetchList(year, term, school, subject, grade, classId)}>
                            查询课表
                        </Button>
                        <Button
                            onPress={() => openInJw("/kbdy/bjkbdy_cxBjkbdyIndex.html?gnmkdm=N214505&layout=default")}>
                            前往教务查询
                        </Button>
                    </Flex>
                    <Button
                        title="导出课表"
                        onPress={() => navigation.navigate("ExportScheduleScreen", {tab: "class"})}
                        containerStyle={{marginVertical: 8, width: "100%"}}
                    />
                </Flex>
                <Divider />
                <Text h4>课表查询结果</Text>
                {loading && <ActivityIndicator animating={loading} />}
                <Flex gap={10} direction="column" align="flex-start">
                    <Flex>
                        <View style={{flex: 1}}>
                            <UnPicker selectedValue={index} onValueChange={setIndex}>
                                {[...list].map((value, index) => {
                                    return <Picker.Item value={index} label={value.className} key={value.id} />;
                                })}
                            </UnPicker>
                        </View>
                    </Flex>
                    <View style={{width: "100%"}}>
                        <Button onPress={() => fetchSchedule()}>查看课表</Button>
                    </View>
                </Flex>
                <Divider />
                {theorySchedule && (
                    <>
                        <Text h4>课表预览</Text>
                        <Divider />
                        <Text>课表周数</Text>
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
                            startDay={startDay}
                            pageView={pageView}
                            scheduleItems={[
                                {
                                    data: theorySchedule,
                                    isItemShow: (item: ScheduleTableItem, day: moment.Moment, week: number) =>
                                        item.week === week && item.day === day.isoWeekday(),
                                    itemRender: (item, day) => (
                                        <NewCourseItem item={item} onPress={() => onItemPress(item, day)} />
                                    ),
                                    isItemStack: (a, b) => a.begin <= b.end && b.begin <= a.end,
                                    stackRender: (items, day, _week, timeRange) => {
                                        const courses = items
                                            .map(i => new CourseClass(i.raw))
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
                        {practicalSchedule && (
                            <>
                                <Card.Divider />
                                <PracticalCourseList courseList={practicalSchedule} />
                            </>
                        )}
                    </>
                )}
                {devMode && (
                    <Flex gap={8} direction="column">
                        <ScheduleDataDebugCard label="查看班级列表" data={list} />
                        <ScheduleDataDebugCard label="查看班级理论课表" data={theorySchedule} />
                        <ScheduleDataDebugCard label="查看班级实践课表" data={practicalSchedule} />
                    </Flex>
                )}
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

const style = StyleSheet.create({
    container: {padding: "5%"},
    label: {textAlign: "right"},
});

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
