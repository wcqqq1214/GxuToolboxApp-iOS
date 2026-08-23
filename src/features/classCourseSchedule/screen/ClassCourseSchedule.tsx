import React, {useCallback, useState} from "react";
import {ActivityIndicator, ScrollView, StyleSheet, View} from "react-native";
import {useNavigation} from "@react-navigation/native";
import {Button, Card, Divider, Text, useTheme} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";
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
import {Icon, UnBottomSheet, UnJsonEditor, UnPressable, UnText} from "@/components/un-ui";

type SheetState =
    | {type: "closed"}
    | {type: "itemDetail"; item: ScheduleTableItem; day: moment.Moment}
    | {type: "courseConflict"; courses: CourseClass[]; day: moment.Moment};

function FilterRow({label, children}: {label: string; children: React.ReactNode}) {
    return (
        <Flex gap={10} align="center">
            <Text style={style.label}>{label}</Text>
            <View style={{flex: 1}}>{children}</View>
        </Flex>
    );
}

export function ClassCourseSchedule() {
    const navigation = useNavigation();
    const {openInJw} = useWebView();
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const devMode = store(s => s.devMode);

    const {store: conflictStore} = useConflictCourseStore();
    const {year, term, setBoth} = useSchoolTerm();

    const {
        school,
        schoolList,
        changeSchool,
        major,
        grade,
        classId,
        setClassId,
        classList,
        majorList,
        changeGrade,
        changeMajor,
        selectedClass,
    } = useFilter({year, term});

    const pageView = usePagerView({pagesAmount: 20});
    const {fetchSchedule, theorySchedule, practiceSchedule, loading, error, hasFetched} = useClassScheduleData();

    const {startDay} = useStartDay(+year, term);

    const [sheet, setSheet] = useState<SheetState>({type: "closed"});

    // 本学期理论课与实践课均无数据时判定为空（用于区分"未查询"与"查无课程"）
    const isEmpty = !theorySchedule?.length && !practiceSchedule?.length;

    const onItemPress = useCallback(
        (item: ScheduleTableItem, day: moment.Moment) => setSheet({type: "itemDetail", item, day}),
        [],
    );

    return (
        <ScrollView>
            <View style={style.container}>
                <Text h4 style={style.sectionTitle}>
                    查询参数
                </Text>
                <Flex gap={8} direction="column" align="stretch" style={{marginTop: 10}}>
                    <FilterRow label="学期">
                        <UnTermSelector year={year} term={term} onChange={setBoth} disableSelectAll />
                    </FilterRow>
                    <FilterRow label="学院">
                        <UnPicker selectedValue={school} onValueChange={changeSchool}>
                            {[["", "全部"], ...schoolList].map(value => (
                                <Picker.Item value={value[0]} label={value[1]} key={value[0]} />
                            ))}
                        </UnPicker>
                    </FilterRow>
                    <FilterRow label="专业">
                        <UnPicker selectedValue={major} onValueChange={changeMajor}>
                            {[["", "全部"]].concat(majorList ?? []).map(value => (
                                <Picker.Item value={value[0]} label={value[1]} key={value[0]} />
                            ))}
                        </UnPicker>
                    </FilterRow>
                    <FilterRow label="年级">
                        <UnPicker selectedValue={grade} onValueChange={changeGrade}>
                            {[["", "全部"], ...Array(25).fill(0)].map((v, index, ori) => {
                                if (v === 0) {
                                    const optionV = 2003 + (ori.length - index);
                                    return <Picker.Item value={String(optionV)} label={optionV + ""} key={optionV} />;
                                } else {
                                    return <Picker.Item value={v[0]} label={v[1]} key={v[0]} />;
                                }
                            })}
                        </UnPicker>
                    </FilterRow>
                    <FilterRow label="班级">
                        <UnPicker selectedValue={classId} onValueChange={setClassId}>
                            {[["", "全部"], ...classList.map(c => [c.classId, c.className] as string[])].map(value => (
                                <Picker.Item value={value[0]} label={value[1]} key={value[0]} />
                            ))}
                        </UnPicker>
                    </FilterRow>

                    <Button
                        containerStyle={{width: "100%"}}
                        loading={loading}
                        disabled={!selectedClass}
                        onPress={() =>
                            fetchSchedule(
                                year,
                                term,
                                selectedClass?.majorId ?? "",
                                selectedClass?.grade ?? "",
                                selectedClass?.classId ?? "",
                            )
                        }>
                        查询课表
                    </Button>
                    <Flex gap={10}>
                        <Button
                            type="outline"
                            containerStyle={{flex: 1}}
                            onPress={() => openInJw("/kbdy/bjkbdy_cxBjkbdyIndex.html?gnmkdm=N214505&layout=default")}>
                            前往教务查询
                        </Button>
                        <Button
                            type="outline"
                            containerStyle={{flex: 1}}
                            title="导出课表"
                            disabled={!selectedClass}
                            onPress={() => navigation.navigate("ExportScheduleScreen", {tab: "class"})}
                        />
                    </Flex>
                </Flex>

                <Divider style={{marginVertical: 12}} />
                <Text h4 style={style.sectionTitle}>
                    课表查询结果
                </Text>
                {loading && <ActivityIndicator animating={loading} style={{paddingVertical: 32}} />}
                {!loading && error && <Text style={style.errorHint}>{error}</Text>}
                {!loading && !error && !hasFetched && <Text style={style.emptyHint}>选择条件后点击「查询课表」</Text>}
                {!loading && !error && hasFetched && isEmpty && (
                    <Text style={style.emptyHint}>该班级本学期暂无课程</Text>
                )}
                {!loading && !error && hasFetched && !isEmpty && (
                    <>
                        {theorySchedule && theorySchedule.length > 0 && (
                            <>
                                <Divider style={{marginVertical: 10}} />
                                <Flex style={{paddingHorizontal: 4, marginVertical: 8}}>
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
                                                const courses = items.map(i => new CourseClass(i.raw)).filter(Boolean);
                                                if (courses.length === 0) return null;
                                                const courseCodes = courses
                                                    .map(c => c._ori.courseName + "_" + c._ori.teacher)
                                                    .sort();
                                                const storedActive = conflictStore.getState().getActive(courseCodes);
                                                const activeCourse =
                                                    storedActive ??
                                                    (courses[0]
                                                        ? courses[0]._ori.courseName + "_" + courses[0]._ori.teacher
                                                        : "");
                                                return (
                                                    <StackCourseItem
                                                        course={courses}
                                                        activeCourse={activeCourse}
                                                        timeRange={timeRange}
                                                        onPress={c =>
                                                            setSheet({type: "courseConflict", courses: c, day})
                                                        }
                                                    />
                                                );
                                            },
                                        } as TimeScheduleItemData,
                                    ]}
                                />
                            </>
                        )}
                        {practiceSchedule && practiceSchedule.length > 0 && (
                            <>
                                <Card.Divider />
                                <PracticalCourseList courseList={practiceSchedule} />
                            </>
                        )}
                    </>
                )}
                {devMode && (
                    <Flex gap={8} direction="column" style={{marginTop: 12}}>
                        <ScheduleDataDebugCard label="查看班级理论课表" data={theorySchedule} />
                        <ScheduleDataDebugCard label="查看班级实践课表" data={practiceSchedule} />
                    </Flex>
                )}
            </View>

            <UnBottomSheet
                isVisible={sheet.type !== "closed"}
                onBackdropPress={() => setSheet({type: "closed"})}
                containerStyle={{borderTopLeftRadius: 12, borderTopRightRadius: 12, padding: 16}}>
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
                                    id: course._ori.courseName,
                                    week: 0,
                                    day: 1 as ScheduleTableItem["day"],
                                    begin: 1 as ScheduleTableItem["begin"],
                                    end: 1 as ScheduleTableItem["begin"],
                                    title: course._ori.courseName,
                                    location: course._ori.venueName,
                                    teacher: course._ori.teacher,
                                    raw: course,
                                },
                            });
                        }}
                    />
                )}
            </UnBottomSheet>
        </ScrollView>
    );
}

const style = StyleSheet.create({
    container: {
        padding: 16,
    },
    sectionTitle: {
        textAlign: "left",
        fontSize: 18,
        fontWeight: "700",
    },
    subTitle: {
        fontSize: 14,
        fontWeight: "600",
        color: "#6B7280",
    },
    label: {
        width: 48,
        textAlign: "right",
        fontSize: 14,
    },
    emptyHint: {
        color: "#9CA3AF",
        textAlign: "center",
        paddingVertical: 32,
    },
    errorHint: {
        color: "#EF4444",
        textAlign: "center",
        paddingVertical: 32,
    },
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
