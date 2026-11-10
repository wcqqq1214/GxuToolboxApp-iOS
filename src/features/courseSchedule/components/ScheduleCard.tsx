import {Divider, Text, useTheme} from "@rneui/themed";
import {StyleSheet, View} from "react-native";
import React, {useEffect, useMemo, useState} from "react";
import Flex from "@/components/un-ui/Flex.tsx";
import {Icon} from "@/components/un-ui/Icon.tsx";
import moment from "moment";
import {getWeekOfDate} from "@/features/courseSchedule/utils/weekOfDate.ts";
import {Color} from "@/shared/color.ts";
import {usePagerView} from "react-native-pager-view";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {UnJsonEditor, UnPressable, UnText} from "@/components/un-ui";
import {TimeScheduleView} from "@/components/tool/infoQuery/courseSchedule/TimeScheduleView.tsx";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount";
import type {ScheduleScope} from "@/features/courseSchedule/repo/personalSchedule";
import {PracticalCourseList} from "@/features/courseSchedule/components/PracticalCourseList.tsx";
import {useJwAuth} from "@/core/auth/Jw/hooks/useJwAuth.ts";
import {useUnifiedAuth} from "@/core/auth/unified/hook/useUnifiedAuth.ts";
import {useAttendanceAuth} from "@/core/auth/attendance/hooks/useAttendanceAuth.ts";
import {CourseClass} from "@/class/jw/course.ts";
import {NextEventBanner} from "@/features/courseSchedule/components/NextEventBanner.tsx";
import {MainBottomSheet} from "@/features/courseSchedule/components/sheets/MainBottomSheet.tsx";
import {useScheduleCardData} from "@/features/courseSchedule/hooks/detail/useScheduleCardData.ts";
import {Schedule} from "gxu-tool-adapters/jw";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {useTimelineLayers} from "@/features/courseSchedule/hooks/useTimelineLayers.tsx";
import {useShift} from "../hooks/detail/useShift";
import {timelineEvents} from "../utils/timelineEvents";

// 菜单的类型
export type SheetState =
    | {type: "closed"}
    | {type: "menu"}
    | {type: "setting"}
    | {type: "share"}
    | {type: "customEvents"; eventId?: number}
    | {type: "courseDetail"; course: Schedule["theoryList"][number]}
    | {type: "examDetail"; exam: ExamWithMeta}
    | {type: "courseConflict"; courses: CourseClass[]; day: moment.Moment};

/**
 * 课表
 * @constructor
 */
export function ScheduleCard() {
    const {store: ucStore} = useUserConfig();
    const devMode = ucStore(s => s.devMode);
    const {theme} = useTheme();

    const {authState: JWAuthState} = useJwAuth();
    const {authState: unifiedAuthState} = useUnifiedAuth();
    const {authState: attendanceAuthState} = useAttendanceAuth();

    const year = +ucStore(s => s.jw.year);
    const term = ucStore(s => s.jw.term);

    const {account} = useJwAccount();
    const logicalTerm =
        term === 1 || term === 3 || term === "3" ? 1 : term === 2 || term === 12 || term === "12" ? 2 : null;
    const inputError = !Number.isInteger(year) || year <= 0 ? "请选择有效学年" : !logicalTerm ? "暂不支持该学期" : null;

    const scope: ScheduleScope | null =
        account?.username && !inputError && logicalTerm ? {username: account.username, year, term: logicalTerm} : null;

    const {
        courseItem,
        examInfo,
        practiceList,
        startDay,
        ready,
        holidayItems,
        refresh,
        refreshing,
        customEvents,
        customItems,
        customOwner,
        weekCount,
    } = useScheduleCardData(year, logicalTerm ?? 1);
    const pagerView = usePagerView({pagesAmount: weekCount || 20});
    const {...rest} = pagerView;

    // 组装网格渲染图层
    const timelineLayers = useTimelineLayers(
        {
            courses: courseItem,
            holidays: holidayItems,
            exams: examInfo,
            startDay,
            customItems,
        },
        {
            onCoursePress: item => setSheet({type: "courseDetail", course: item.raw}),
            onExamPress: exam => setSheet({type: "examDetail", exam}),
            onConflictPress: (courses, day) => setSheet({type: "courseConflict", courses, day}),
            onCustomEventPress: eventId => setSheet({type: "customEvents", eventId}),
        },
    );
    const practiceItems = practiceList ?? [];

    const shiftRules = useShift().store(state => state.shiftRules);
    const allScheduleEvents = useMemo(
        () => timelineEvents(timelineLayers, startDay, shiftRules),
        [timelineLayers, startDay, shiftRules],
    );

    const [sheet, setSheet] = useState<SheetState>({type: "closed"});

    useEffect(() => {
        setSheet({type: "closed"});
    }, [scope?.username, year, term, customOwner]);

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
                    <UnPressable
                        onPress={() => {
                            refresh();
                        }}
                        disabled={refreshing || !scope}>
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
            <NextEventBanner items={allScheduleEvents} startDay={startDay} ready={ready} />
            <TimeScheduleView
                showDate
                showTimeSpanHighlight
                showDayHighlight
                startDay={startDay}
                pageView={pagerView}
                scheduleItems={timelineLayers}
            />
            <Divider />
            <PracticalCourseList courseList={practiceItems} />
            {devMode && (
                <Flex gap={8} style={{paddingHorizontal: 12}} direction="column">
                    <ScheduleDataDebugCard label="查看课程数据" data={courseItem} />
                    <ScheduleDataDebugCard label="查看实践课数据" data={practiceItems} />
                </Flex>
            )}
            <MainBottomSheet
                sheet={sheet}
                setSheet={setSheet}
                pageViewRest={rest}
                examInfo={examInfo}
                customEvents={customEvents}
                year={year}
                term={logicalTerm ?? 1}
                weekCount={weekCount}
            />
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
