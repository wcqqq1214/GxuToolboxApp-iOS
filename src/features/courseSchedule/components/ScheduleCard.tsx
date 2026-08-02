import {BottomSheet, Divider, Text, useTheme} from "@rneui/themed";
import {StyleSheet, View} from "react-native";
import React, {useCallback, useEffect, useMemo, useState} from "react";
import Flex from "@/components/un-ui/Flex.tsx";
import {Icon} from "@/components/un-ui/Icon.tsx";
import moment from "moment";
import {SchoolTermValue} from "@/type/global.ts";
import {Color} from "@/shared/color.ts";
import {usePagerView} from "react-native-pager-view";
import {CourseCardSetting} from "@/components/tool/infoQuery/courseSchedule/CourseCardSetting.tsx";
import {useNavigation} from "@react-navigation/native";
import {ScheduleShareSheet} from "@/components/tool/infoQuery/courseSchedule/ScheduleShareSheet.tsx";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {UnJsonEditor, UnPressable, UnText} from "@/components/un-ui";
import {TimeScheduleView} from "@/components/tool/infoQuery/courseSchedule/TimeScheduleView.tsx";
import {ScheduleTableItem, TimeScheduleItemData} from "@/features/courseSchedule/type/schedule.ts";
import {useCourse} from "@/features/courseSchedule/hooks/detail/useCourse.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {useExam} from "@/features/courseSchedule/hooks/detail/useExam.ts";
import {useNextEvent} from "@/features/courseSchedule/hooks/detail/useNextCourse.ts";
import {usePractice} from "@/features/courseSchedule/hooks/detail/usePractice.ts";
import {PracticalCourseList} from "@/features/courseSchedule/components/PracticalCourseList.tsx";
import {CourseDetail} from "@/features/courseSchedule/components/CourseDetail.tsx";
import {usePhyExp} from "@/features/courseSchedule/hooks/detail/usePhyExp.ts";
import {useHoliday} from "@/features/courseSchedule/hooks/detail/useHoliday.ts";
import {defaultItems} from "@/features/courseSchedule/utils/defaultItems.ts";
import {useJwAuth} from "@/core/auth/Jw/hooks/useJwAuth.ts";
import {AuthStatusSection} from "@/features/courseSchedule/components/AuthStatusSection.tsx";
import {useUnifiedAuth} from "@/core/auth/unified/hook/useUnifiedAuth.ts";
import {useAttendanceAuth} from "@/core/auth/attendance/hooks/useAttendanceAuth.ts";
import {NewCourseItem} from "@/features/courseSchedule/components/NewCourseItem.tsx";
import {NewExamItem} from "@/features/courseSchedule/components/NewExamItem.tsx";
import {HolidayItem} from "@/features/courseSchedule/components/HolidayItem.tsx";
import {Course} from "@/type/infoQuery/course/course.ts";
import {CourseClass} from "@/class/jw/course.ts";
import {StackCourseItem} from "@/features/courseSchedule/components/StackCourseItem.tsx";
import {useConflictCourseStore} from "@/features/courseSchedule/stores/useConflictCourseStore.ts";
import {ConflictCourseSheet} from "@/features/courseSchedule/components/ConflictCourseList.tsx";
import {ExamInfo} from "@/type/infoQuery/exam/examInfo.ts";
import {ExamInfoClass} from "@/class/jw/exam.ts";
import {ExamDetail} from "@/components/tool/infoQuery/examInfo/ExamDetail.tsx";
import {JwMachine} from "@/core/auth/Jw/JwMachine.ts";
import {AuthStateMap} from "@/core/auth/auth.type.ts";
import {switchByField} from "@/utils/objectUtils.ts";

// 菜单的类型
type SheetState =
    | {type: "closed"}
    | {type: "menu"}
    | {type: "setting"}
    | {type: "share"}
    | {type: "itemDetail"; item: ScheduleTableItem; day: moment.Moment}
    | {type: "courseConflict"; courses: CourseClass[]; day: moment.Moment};

/**
 * 课表
 * @constructor
 */
export function ScheduleCard() {
    const {store: ucStore} = useUserConfig();
    const devMode = ucStore(s => s.devMode);
    const navigation = useNavigation();
    const {theme} = useTheme();
    const pagerView = usePagerView({pagesAmount: 20});
    const {...rest} = pagerView;

    const {store: conflictStore} = useConflictCourseStore();

    const {init: initPhyExp, patchItem, patchCourse} = usePhyExp();

    const {authState: JWAuthState} = useJwAuth();
    const {authState: unifiedAuthState} = useUnifiedAuth();
    const {authState: attendanceAuthState} = useAttendanceAuth();

    const [year, setYear] = useState(+ucStore(s => s.jw.year));
    const [term, setTerm] = useState<SchoolTermValue>(ucStore(s => s.jw.term));
    const startDay = useStartDay(year, term);

    const {items: courseItems = [], refresh: refreshCourse} = useCourse(year, term);
    const {store: examStore, init: initExam, loadCache: loadExamCache} = useExam();
    const examItems = examStore(s => s.examList) || [];
    const holidayItems = useHoliday(year, term) ?? [];
    const {items: practiceItems = [], refresh: refreshPractice} = usePractice(year, term);

    async function init() {
        // 同步加载MMKV缓存到store，避免等待网络时页面空白
        loadExamCache();

        if (JWAuthState.status !== AuthStateMap.Authenticated) {
            await JwMachine.refreshToken();
        } else {
            // 异步拉取最新考试和物理实验数据
            await initExam(year, term, startDay);
            await initPhyExp();
        }
    }

    useEffect(() => {
        init();
    }, [year, term]);

    const defaultItem: ScheduleTableItem[] = useMemo(
        () => (JWAuthState.status !== "no_account" ? [] : defaultItems),
        [JWAuthState.status],
    );

    const rawItems: ScheduleTableItem[] = useMemo(
        () => [...courseItems, ...examItems, ...holidayItems, ...defaultItem],
        [courseItems, examItems, holidayItems, defaultItem],
    );
    const [sheet, setSheet] = useState<SheetState>({type: "closed"});

    const onItemPress = useCallback(
        (item: ScheduleTableItem, day: moment.Moment) => setSheet({type: "itemDetail", item, day}),
        [],
    );

    const scheduleItems: TimeScheduleItemData[] = useMemo(
        () =>
            [
                {
                    data: courseItems,
                    itemRender: (item, day) => (
                        <NewCourseItem item={patchItem(item, day)} onPress={() => onItemPress(item, day)} />
                    ),
                    isItemStack: (a, b) => a.begin <= b.end && b.begin <= a.end,
                    stackRender: (items, day, _week, timeRange) => {
                        const courses = items.map(i => patchCourse(new CourseClass(i.raw), day)).filter(Boolean);
                        if (courses.length === 0) return null;
                        const courseCodes = courses
                            .map(c => c.transformed.courseCode + "_" + c.transformed.staffId)
                            .sort();
                        const storedActive = conflictStore.getState().getActive(courseCodes);
                        const activeCourse =
                            storedActive ??
                            (courses[0]
                                ? courses[0].transformed.courseCode + "_" + courses[0].transformed.staffId
                                : "");
                        return (
                            <StackCourseItem
                                course={courses}
                                activeCourse={activeCourse}
                                timeRange={timeRange}
                                onPress={c => setSheet({type: "courseConflict", courses: c, day})}
                            />
                        );
                    },
                } as TimeScheduleItemData<ScheduleTableItem<Course>>,
                {
                    data: examItems,
                    itemRender: (item, day) => <NewExamItem item={item} onPress={() => onItemPress(item, day)} />,
                } as TimeScheduleItemData<ScheduleTableItem<ExamInfo>>,
                {
                    data: holidayItems,
                    needShift: false,
                    itemRender: (item, day) => <HolidayItem item={item} />,
                },
                {
                    data: defaultItem,
                    itemRender: (item, day) => <NewCourseItem item={item} onPress={() => onItemPress(item, day)} />,
                },
            ]
                .filter(td => td.data.length > 0)
                .map(td => ({
                    ...td,
                    isItemShow: (item: ScheduleTableItem, day: moment.Moment, week: number) => {
                        return item.week === week && item.day === day.isoWeekday();
                    },
                })),
        [courseItems, examItems, holidayItems, defaultItem, onItemPress],
    );

    const realCurrentWeek = Math.ceil(moment.duration(moment().diff(startDay)).asWeeks());

    const [refreshing, setRefreshing] = useState(false);

    const handleRefresh = useCallback(async () => {
        setRefreshing(true);
        try {
            await Promise.all([refreshCourse(), initExam(year, term, startDay)]);
        } finally {
            setRefreshing(false);
        }
    }, [refreshCourse, initExam, year, term, startDay]);

    const baseColor = theme.colors.primary;
    const backgroundColor = Color(baseColor).setAlpha(theme.mode === "light" ? 0.3 : 0.1).rgbaString;
    const textColor = Color.mix(baseColor, theme.colors.black, 0.5).rgbaString;

    const style = useMemo(
        () =>
            StyleSheet.create({
                bottomSheetContainer: {
                    backgroundColor: theme.colors.background,
                    padding: "5%",
                    borderTopLeftRadius: 8,
                    borderTopRightRadius: 8,
                    borderColor: Color.mix(theme.colors.primary, theme.colors.background, 0.8).rgbaString,
                    borderWidth: 1,
                },
                cardTitle: {
                    paddingHorizontal: 12,
                },
                menuItem: {
                    flexDirection: "row",
                    gap: 16,
                    paddingVertical: 14,
                    paddingHorizontal: 8,
                    alignItems: "center",
                    borderBottomWidth: StyleSheet.hairlineWidth,
                    borderBottomColor: theme.colors.greyOutline,
                },
                nextCourse: {
                    paddingHorizontal: 12,
                    paddingVertical: 10,
                    borderRadius: 8,
                    marginHorizontal: 6,
                    justifyContent: "center",
                    alignItems: "center",
                    backgroundColor: backgroundColor,
                },
            }),
        [theme],
    );

    return (
        <View>
            <Flex justify="space-between" style={style.cardTitle}>
                <Flex direction="row" align="center" gap={8}>
                    <Text h4>日程表</Text>
                    <UnPressable
                        onPress={function () {
                            return setSheet({type: "menu"});
                        }}
                        style={{flexDirection: "row", alignItems: "center", gap: 8}}>
                        {[JWAuthState, unifiedAuthState, attendanceAuthState].map((i, idx) =>
                            i?.status !== "authenticated" ? (
                                <Icon
                                    key={idx}
                                    name="account-network-off-outline"
                                    size={24}
                                    color={theme.colors.error}
                                />
                            ) : (
                                <Icon key={idx} name="account-network-outline" size={24} color={theme.colors.success} />
                            ),
                        )}
                    </UnPressable>
                </Flex>
                <Flex gap={15} justify="flex-end">
                    <UnPressable onPress={handleRefresh} disabled={refreshing}>
                        <Icon
                            name={refreshing ? "loading" : "refresh"}
                            size={24}
                            style={refreshing ? {opacity: 0.5} : undefined}
                        />
                    </UnPressable>
                    {rest.activePage + 1 !== realCurrentWeek && (
                        <UnPressable
                            onPress={function () {
                                return rest.setPage(realCurrentWeek - 1);
                            }}>
                            <Icon name="history" size={24} />
                        </UnPressable>
                    )}
                    <UnPressable
                        onPress={function () {
                            return setSheet({type: "menu"});
                        }}>
                        <Icon name="menu" size={24} />
                    </UnPressable>
                </Flex>
            </Flex>
            <Divider />
            <NextEventBanner />
            <TimeScheduleView
                showDate
                showTimeSpanHighlight
                showDayHighlight
                startDay={startDay}
                pageView={pagerView}
                scheduleItems={scheduleItems}
            />
            <Divider />
            <PracticalCourseList courseList={practiceItems} />
            {devMode && (
                <Flex gap={8} style={{paddingHorizontal: 12}} direction="column">
                    <ScheduleDataDebugCard label="查看课程数据" data={rawItems} />
                    <ScheduleDataDebugCard label="查看实践课数据" data={practiceItems} />
                </Flex>
            )}
            <BottomSheet isVisible={sheet.type !== "closed"} onBackdropPress={() => setSheet({type: "closed"})}>
                <View style={style.bottomSheetContainer}>
                    {sheet.type === "menu" && (
                        <>
                            <AuthStatusSection
                                jwAuth={JWAuthState}
                                unifiedAuth={unifiedAuthState}
                                attendanceAuth={attendanceAuthState}
                                menuItemStyle={style.menuItem}
                            />
                            <UnPressable
                                onPress={function () {
                                    setSheet({type: "closed"});
                                    navigation.navigate("ScheduleEdit");
                                }}>
                                <View style={style.menuItem}>
                                    <Icon name="table-edit" size={22} />
                                    <UnText>事件编辑</UnText>
                                </View>
                            </UnPressable>
                            <UnPressable
                                onPress={function () {
                                    return setSheet({type: "share"});
                                }}>
                                <View style={style.menuItem}>
                                    <Icon type="antdesign" name="share-alt" size={22} />
                                    <UnText>分享课表</UnText>
                                </View>
                            </UnPressable>
                            <UnPressable
                                onPress={function () {
                                    return setSheet({type: "setting"});
                                }}>
                                <View style={style.menuItem}>
                                    <Icon name="cog" size={22} />
                                    <UnText>课表设置</UnText>
                                </View>
                            </UnPressable>
                        </>
                    )}
                    {sheet.type === "setting" && (
                        <CourseCardSetting
                            year={year}
                            term={term}
                            pageViewRest={rest}
                            onYearChange={setYear}
                            onTermChange={setTerm}
                        />
                    )}
                    {sheet.type === "itemDetail" && sheet.item.kind === "exam" && sheet.item.raw && (
                        <ExamDetail examInfo={new ExamInfoClass(sheet.item.raw as ExamInfo)} />
                    )}
                    {sheet.type === "itemDetail" &&
                        sheet.item?.raw &&
                        sheet.item.kind !== "exam" &&
                        (() => {
                            const course = patchCourse(new CourseClass(sheet.item.raw), sheet.day);
                            const courseName = course.transformed.courseName;
                            const matchedExam = examItems
                                .filter(e => e.raw?.kcmc === courseName)
                                ?.map(e => new ExamInfoClass(e.raw as ExamInfo));
                            return (
                                <CourseDetail
                                    course={course}
                                    examInfo={matchedExam}
                                    onExamPress={exam => {
                                        const examDate = moment(exam.transformed.examTime.slice(0, 10));
                                        const week = examDate.diff(startDay, "week") + 1;
                                        rest.setPage(week - 1);
                                        setSheet({
                                            type: "itemDetail",
                                            day: examDate,
                                            item: {
                                                id: exam.transformed.courseCode,
                                                week,
                                                day: examDate.isoWeekday() as ScheduleTableItem["day"],
                                                begin: 1 as ScheduleTableItem["begin"],
                                                end: 1 as ScheduleTableItem["begin"],
                                                title: exam.transformed.courseName,
                                                location: exam.transformed.venueName,
                                                kind: "exam",
                                                raw: exam._ori,
                                            },
                                        });
                                    }}
                                />
                            );
                        })()}
                    {sheet.type === "share" && (
                        <ScheduleShareSheet week={rest.activePage + 1} onClose={() => setSheet({type: "closed"})} />
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
        </View>
    );
}

function NextEventBanner() {
    const nextEvent = useNextEvent();
    const {store: ucStore} = useUserConfig();
    const year = +ucStore(s => s.jw.year);
    const term = ucStore(s => s.jw.term);
    const startDay = useStartDay(year, term);
    const {theme} = useTheme();
    const baseColor = theme.colors.primary;
    const backgroundColor = Color(baseColor).setAlpha(theme.mode === "light" ? 0.3 : 0.1).rgbaString;
    const textColor = Color.mix(baseColor, theme.colors.black, 0.5).rgbaString;

    const daysFromNow = (item: {week: number; day: number}) => {
        if (!startDay) return "未知时间";
        const eventDay = startDay
            .clone()
            .add(item.week - 1, "weeks")
            .add(item.day - 1, "days")
            .startOf("day");
        const diff = eventDay.diff(moment().startOf("day"), "days");
        if (diff <= 0) return "今天";
        if (diff === 1) return "明天";
        return `${diff}天后`;
    };

    const style = StyleSheet.create({
        container: {
            paddingHorizontal: 12,
            paddingVertical: 10,
            borderRadius: 8,
            marginHorizontal: 6,
            justifyContent: "center",
            alignItems: "center",
            backgroundColor: backgroundColor,
        },
    });

    if (!nextEvent && startDay) {
        const updateTime = startDay.add(20, "week").format("MM月DD日");
        return (
            <View style={style.container}>
                <Text style={{fontSize: 16, color: textColor}}>所有活动已结束，将在{updateTime}更新至下个学期</Text>
            </View>
        );
    }

    return (
        <View style={style.container}>
            <Text style={{fontSize: 18, color: textColor}}>
                {switchByField(nextEvent, "kind", {
                    course: ev => `下节课：${ev.title}${ev.location ? ` · ${ev.location}` : ""}`,
                    exam: ev => `下场考试：${ev.title}${ev.location ? ` · ${ev.location}` : ""}（${daysFromNow(ev)}）`,
                    holiday: ev => `下个假期：${ev.title}（${daysFromNow(ev)}）`,
                })}
            </Text>
        </View>
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
