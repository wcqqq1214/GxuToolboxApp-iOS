import {Divider, Text, useTheme} from "@rneui/themed";
import {StyleSheet, View} from "react-native";
import React, {useCallback, useEffect, useMemo, useState} from "react";
import Flex from "@/components/un-ui/Flex.tsx";
import {Icon} from "@/components/un-ui/Icon.tsx";
import moment from "moment";
import {getWeekOfDate} from "@/features/courseSchedule/utils/weekOfDate.ts";
import {Color} from "@/shared/color.ts";
import {usePagerView} from "react-native-pager-view";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {UnBottomSheet, UnJsonEditor, UnPressable, UnText} from "@/components/un-ui";
import {TimeScheduleView} from "@/components/tool/infoQuery/courseSchedule/TimeScheduleView.tsx";
import {ScheduleTableItem, ScheduleTableItemV2, TimeScheduleItemData} from "@/features/courseSchedule/type/schedule.ts";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount";
import type {ScheduleScope} from "@/features/courseSchedule/repo/personalSchedule";
import {PracticalCourseList} from "@/features/courseSchedule/components/PracticalCourseList.tsx";
import {CourseDetail} from "@/features/courseSchedule/components/CourseDetail.tsx";
import {useJwAuth} from "@/core/auth/Jw/hooks/useJwAuth.ts";
import {useUnifiedAuth} from "@/core/auth/unified/hook/useUnifiedAuth.ts";
import {useAttendanceAuth} from "@/core/auth/attendance/hooks/useAttendanceAuth.ts";
import {NewCourseItem} from "@/features/courseSchedule/components/NewCourseItem.tsx";
import {CourseClass} from "@/class/jw/course.ts";
import {StackCourseItem} from "@/features/courseSchedule/components/StackCourseItem.tsx";
import {useConflictCourseStore} from "@/features/courseSchedule/stores/useConflictCourseStore.ts";
import {ConflictCourseSheet} from "@/features/courseSchedule/components/ConflictCourseList.tsx";
import {NextEventBanner} from "@/features/courseSchedule/components/NextEventBanner.tsx";
import {MainBottomSheet} from "@/features/courseSchedule/components/sheets/MainBottomSheet.tsx";
import {useScheduleCardData} from "@/features/courseSchedule/hooks/detail/useScheduleCardData.ts";
import {Schedule} from "gxu-tool-adapters/jw";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";

// 菜单的类型
export type SheetState =
    | {type: "closed"}
    | {type: "menu"}
    | {type: "setting"}
    | {type: "share"}
    | {type: "courseDetail"; course: Schedule["theoryList"][number]}
    | {type: "examDetail"; exam: ExamWithMeta}
    | {type: "itemDetail"; item: ScheduleTableItem; day: moment.Moment}
    | {type: "courseConflict"; courses: CourseClass[]; day: moment.Moment};

/**
 * 课表
 * @constructor
 */
export function ScheduleCard() {
    const {store: ucStore} = useUserConfig();
    const devMode = ucStore(s => s.devMode);
    const {theme} = useTheme();
    const pagerView = usePagerView({pagesAmount: 20});
    const {...rest} = pagerView;

    const {store: conflictStore} = useConflictCourseStore();

    const {authState: JWAuthState} = useJwAuth();
    const {authState: unifiedAuthState} = useUnifiedAuth();
    const {authState: attendanceAuthState} = useAttendanceAuth();

    const year = +ucStore(s => s.jw.year);
    const term = ucStore(s => s.jw.term);

    const {account, hydrating} = useJwAccount();
    const logicalTerm =
        term === 1 || term === 3 || term === "3" ? 1 : term === 2 || term === 12 || term === "12" ? 2 : null;
    const inputError = !Number.isInteger(year) || year <= 0 ? "请选择有效学年" : !logicalTerm ? "暂不支持该学期" : null;
    const scope: ScheduleScope | null =
        account?.username && !inputError && logicalTerm ? {username: account.username, year, term: logicalTerm} : null;
    // const {schedule, status, refresh, error} = usePersonalCourseData(scope);
    // const courseItems = useMemo(() => (schedule ? normalizeCourse(schedule) : []), [schedule]);

    const {courseItem, practiceList, startDay, ready, termReady} = useScheduleCardData(year, logicalTerm ?? 1);
    const practiceItems = practiceList ?? [];

    const [sheet, setSheet] = useState<SheetState>({type: "closed"});
    useEffect(() => {
        setSheet(current =>
            current.type === "itemDetail" || current.type === "courseConflict" || current.type === "share"
                ? {type: "closed"}
                : current,
        );
    }, [scope?.username, year, term]);

    const onItemPress = useCallback((item: ScheduleTableItem) => {
        if (item.kind === "exam") {
            setSheet({type: "examDetail", exam: item.raw});
        } else {
            setSheet({type: "courseDetail", course: item.raw});
        }
    }, []);

    const scheduleItems: TimeScheduleItemData[] = useMemo(
        () =>
            [
                {
                    data: courseItem,
                    showPreShiftItems: true,
                    itemRender: (item, day) => <NewCourseItem item={item} onPress={() => onItemPress(item, day)} />,
                    isItemStack: (a, b) => a.begin <= b.end && b.begin <= a.end,
                    stackRender: (items, day, _week, timeRange) => {
                        const courses = items.map(i => new CourseClass(i.raw));
                        if (courses.length === 0) return null;
                        const courseCodes = courses.map(c => c._ori.courseName + "_" + c._ori.teacher).sort();
                        const storedActive = conflictStore.getState().getActive(courseCodes);
                        const activeCourse =
                            storedActive ??
                            (courses[0] ? courses[0]._ori.courseName + "_" + courses[0]._ori.teacher : "");
                        return (
                            <StackCourseItem
                                course={courses}
                                activeCourse={activeCourse}
                                timeRange={timeRange}
                                onPress={c => setSheet({type: "courseConflict", courses: c, day})}
                            />
                        );
                    },
                } as TimeScheduleItemData<ScheduleTableItem>,
            ]
                .filter(td => td.data.length > 0)
                .map(td => ({
                    ...td,
                    isItemShow: (item: ScheduleTableItem, day: moment.Moment, week: number) => {
                        return item.week === week && item.day === day.isoWeekday();
                    },
                })),
        [courseItem, onItemPress, conflictStore],
    );

    const realCurrentWeek = getWeekOfDate(moment(), startDay);

    const style = useMemo(
        () =>
            StyleSheet.create({
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
                    {/*<UnPressable*/}
                    {/*    onPress={() => {*/}
                    {/*        refresh();*/}
                    {/*    }}*/}
                    {/*    disabled={refreshing || !scope}>*/}
                    {/*    <Icon*/}
                    {/*        name={refreshing ? "loading" : "refresh"}*/}
                    {/*        size={24}*/}
                    {/*        style={refreshing ? {opacity: 0.5} : undefined}*/}
                    {/*    />*/}
                    {/*</UnPressable>*/}
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
            <NextEventBanner items={courseItem} startDay={startDay} ready={ready} />
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
                    <ScheduleDataDebugCard label="查看课程数据" data={courseItem} />
                    <ScheduleDataDebugCard label="查看实践课数据" data={practiceItems} />
                </Flex>
            )}
            <MainBottomSheet sheet={sheet} setSheet={setSheet} pageViewRest={rest} />
            <UnBottomSheet
                isVisible={sheet.type !== "closed" && sheet.type !== "menu" && sheet.type !== "setting"}
                onBackdropPress={() => setSheet({type: "closed"})}
                containerStyle={{padding: "5%"}}>
                {/*{sheet.type === "itemDetail" &&*/}
                {/*    sheet.item &&*/}
                {/*    (() => {*/}
                {/*        return <CourseDetail course={new CourseClass(sheet.item.raw)} />;*/}
                {/*    })()}*/}
                {/*{sheet.type === "share" && (*/}
                {/*    <ScheduleShareSheet*/}
                {/*        week={rest.activePage + 1}*/}
                {/*        schedule={schedule}*/}
                {/*        startDay={startDay}*/}
                {/*        onClose={() => setSheet({type: "closed"})}*/}
                {/*    />*/}
                {/*)}*/}
                {sheet.type === "courseDetail" && sheet.course && <CourseDetail course={sheet.course} />}
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
                    <Icon name="console" size={16} />
                    <UnText weight="bold" size={16}>
                        {label}
                    </UnText>
                </Flex>
            </UnPressable>
            <UnJsonEditor.Modal readOnly visible={modalOpen} onClose={() => setModalOpen(false)} value={data} />
        </Flex>
    );
}
