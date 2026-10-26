import {useCallback, useEffect, useMemo, useRef, useState} from "react";
import {ActivityIndicator, ScrollView, StyleSheet, View} from "react-native";
import {useNavigation, type NavigationProp, type ParamListBase} from "@react-navigation/native";
import {Button, useTheme} from "@rneui/themed";
import {usePagerView} from "react-native-pager-view";
import moment from "moment";
import {Flex, Icon, UnPressable, UnTermSelector, UnText} from "@/components/un-ui";
import {TimeScheduleView} from "@/components/tool/infoQuery/courseSchedule/TimeScheduleView.tsx";
import type {TimeScheduleItemData} from "@/features/courseSchedule/type/schedule.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {EmptyRunBlock} from "../components/EmptyRunBlock";
import {RoomPickerSheet} from "../components/RoomPickerSheet";
import {WeekStatusOverlay, type WeekStatusKind} from "../components/WeekStatusOverlay";
import {useEmptyClassroomOverview} from "../hooks/useEmptyClassroomOverview";
import {useSelection, useSelectionActions, useSelectionInit, useSelectionTermSwitcher} from "../stores/selectionStore";
import {useCacheRunnerStore, type CacheTask} from "../stores/cacheRunnerStore";
import type {FreeRunItem} from "../type";
import {DAYS, EMPTY_CLASSROOM_NEED_SHIFT, MAX_WEEKS} from "../utils/constants";
import {toLegacyTerm} from "../utils/terms";

type OverlayConfig = {
    kind: WeekStatusKind;
    mode: "full" | "banner";
    week?: number;
    completedDays?: number;
    task?: CacheTask | null;
    actionLabel?: string;
    onAction?: () => void;
};

/** 空闲段渲染；定义在组件外，避免每次渲染产生新的组件类型。 */
function renderEmptyRun(item: FreeRunItem) {
    return <EmptyRunBlock item={item} />;
}

/** 第一屏显示的教学周日期范围，例如 "9.21–9.27"。 */
function formatWeekRange(startDay: moment.MomentInput, week: number): string {
    const begin = moment(startDay);
    if (!begin.isValid()) return "";

    const start = begin.clone().add((week - 1) * 7, "days");
    const end = start.clone().add(6, "days");
    return `${start.month() + 1}.${start.date()}–${end.month() + 1}.${end.date()}`;
}

/**
 * 作用：空闲教室第一屏；选择学期/周/教室后从本地缓存渲染该教室的空闲时间段。
 * 修改注意：
 * - pager 只在 selection.week 被外部改变（切学期、初始化）时单向 setPage；
 *   用户滑动由 onPageChanged 写 store，禁止用 effect 读 pageView.activePage 覆盖 store；
 * - 未缓存/未选教室的完整覆盖层只包住 pager，卡片外仍可左右滑周；
 * - 本地读库失败只在页面内联提示 + 重试，不弹 Toast。
 */
export function EmptyClassroomScreen() {
    useSelectionInit();
    const navigation = useNavigation<NavigationProp<ParamListBase>>();
    const {theme} = useTheme();
    const selection = useSelection();
    const {setWeek, setRoom} = useSelectionActions();
    const switchTerm = useSelectionTermSwitcher();
    const {startDay, ready} = useStartDay(selection.year, selection.term);

    const pageView = usePagerView({pagesAmount: MAX_WEEKS});
    const {activePage, setPage} = pageView;
    const [roomSheetVisible, setRoomSheetVisible] = useState(false);

    const overview = useEmptyClassroomOverview({
        year: selection.year,
        term: selection.term,
        roomId: selection.roomId,
        activeWeek: selection.week,
        enabled: selection.hydrated,
    });
    // overview 不返回 runner task；第一屏需要它显示当前周的缓存进度。
    const runnerTask = useCacheRunnerStore(state => state.task);

    const internalWeekRef = useRef<number | null>(null);
    const handlePageChanged = useCallback(
        (pageIndex: number) => {
            const nextWeek = pageIndex + 1;
            internalWeekRef.current = nextWeek;
            setWeek(nextWeek);
        },
        [setWeek],
    );

    // 只同步外部周次变化；用户滑动的周次已经由 handlePageChanged 写入 store。
    useEffect(() => {
        if (!selection.hydrated) return;
        if (internalWeekRef.current === selection.week) return;
        internalWeekRef.current = selection.week;
        if (activePage !== selection.week - 1) {
            setPage(selection.week - 1);
        }
    }, [selection.hydrated, selection.week, activePage, setPage]);

    const openCacheManager = useCallback(() => {
        navigation.navigate("emptyClassroomCache");
    }, [navigation]);
    const openRoomPicker = useCallback(() => setRoomSheetVisible(true), []);
    const closeRoomPicker = useCallback(() => setRoomSheetVisible(false), []);

    const activeTask =
        runnerTask &&
        runnerTask.year === selection.year &&
        runnerTask.term === selection.term &&
        runnerTask.week === selection.week
            ? runnerTask
            : null;
    const activeSnapshot = overview.snapshotByWeek.get(selection.week) ?? null;
    const activeCompletedDays = activeSnapshot?.completedDays ?? 0;
    const hasCachedWeeks = overview.snapshots.length > 0;
    const weekLoaded = overview.loadedWeeks.has(selection.week);

    const freeCount = useMemo(
        () =>
            overview.runs.reduce(
                (total, run) => (run.week === selection.week ? total + run.end - run.begin + 1 : total),
                0,
            ),
        [overview.runs, selection.week],
    );

    const overlay = useMemo<OverlayConfig | null>(() => {
        if (!selection.hydrated) return null;

        if (activeTask) {
            const hasDays = activeTask.completedDays.length > 0;
            return {
                kind: "running",
                mode: hasDays ? "banner" : "full",
                task: activeTask,
                actionLabel: "查看详情",
                onAction: openCacheManager,
            };
        }

        // 加载/读库失败期间不显示基于旧数据的覆盖提示，避免误导。
        if (overview.loading || overview.error) return null;

        if (!hasCachedWeeks) {
            return {
                kind: "no-cache",
                mode: "full",
                actionLabel: "去缓存管理",
                onAction: openCacheManager,
            };
        }

        if (!activeSnapshot || activeCompletedDays === 0) {
            return {
                kind: "week-uncached",
                mode: "full",
                week: selection.week,
                actionLabel: "去缓存",
                onAction: openCacheManager,
            };
        }

        if (activeCompletedDays < DAYS) {
            return {
                kind: "incomplete",
                mode: "banner",
                week: selection.week,
                completedDays: activeCompletedDays,
                actionLabel: "去缓存/继续",
                onAction: openCacheManager,
            };
        }

        if (!selection.roomId) {
            return {
                kind: "no-room",
                mode: "full",
                actionLabel: "选择教室",
                onAction: openRoomPicker,
            };
        }

        if (weekLoaded && freeCount === 0) {
            return {kind: "no-free", mode: "banner", week: selection.week, title: "本周该教室无空闲"};
        }

        return null;
    }, [
        selection.hydrated,
        selection.week,
        selection.roomId,
        activeTask,
        overview.loading,
        overview.error,
        hasCachedWeeks,
        activeSnapshot,
        activeCompletedDays,
        weekLoaded,
        freeCount,
        openCacheManager,
        openRoomPicker,
    ]);

    const statusText = useMemo(() => {
        if (overview.loading) return "加载中";
        if (overview.error) return "加载失败";
        if (!hasCachedWeeks) return "未缓存";
        if (!activeSnapshot || activeCompletedDays === 0) return "未缓存";
        if (!weekLoaded) return "加载中";
        if (!selection.roomId) return "未选择教室";
        return `空闲 ${freeCount} 节`;
    }, [
        overview.loading,
        overview.error,
        hasCachedWeeks,
        activeSnapshot,
        activeCompletedDays,
        weekLoaded,
        selection.roomId,
        freeCount,
    ]);

    const scheduleItems = useMemo<TimeScheduleItemData<FreeRunItem>[]>(
        () => [
            {
                data: overview.runs,
                needShift: EMPTY_CLASSROOM_NEED_SHIFT,
                isItemShow: (item, day, week) => item.week === week && item.day === day.isoWeekday(),
                itemRender: renderEmptyRun,
            },
        ],
        [overview.runs],
    );

    if (!selection.hydrated) {
        return (
            <View style={styles.center}>
                <ActivityIndicator color={theme.colors.primary} />
            </View>
        );
    }

    const legacyTerm = toLegacyTerm(selection.term);
    const weekRange = ready ? formatWeekRange(startDay, selection.week) : "";
    const room = overview.room;
    const roomLabel = room ? `${room.building} · ${room.name}` : selection.roomId ? "正在加载教室信息..." : "选择教室";
    const roomMeta = room
        ? [room.placeType, room.seatCount !== null ? `${room.seatCount} 座` : ""].filter(Boolean).join(" · ")
        : "";

    return (
        <>
            <ScrollView contentContainerStyle={styles.container}>
                <View style={styles.filterRow}>
                    <UnText size={14} style={styles.filterLabel}>
                        学期
                    </UnText>
                    <View style={styles.filterContent}>
                        <UnTermSelector
                            key={`${selection.year}-${legacyTerm}`}
                            year={selection.year}
                            term={legacyTerm}
                            disableSelectAll
                            onChange={switchTerm}
                        />
                    </View>
                </View>

                <View style={styles.filterRow}>
                    <UnText size={14} style={styles.filterLabel}>
                        教室
                    </UnText>
                    <View style={styles.filterContent}>
                        <UnPressable
                            style={[
                                styles.roomButton,
                                {borderColor: theme.colors.grey4, backgroundColor: theme.colors.grey5},
                            ]}
                            onPress={openRoomPicker}>
                            <Flex justify="space-between" align="center" gap={8}>
                                <Flex inline align="center" gap={6} style={styles.roomLabel}>
                                    <Icon name="door" size={18} color={theme.colors.grey2} />
                                    <UnText size={15} numberOfLines={1} style={styles.roomText}>
                                        {roomLabel}
                                    </UnText>
                                </Flex>
                                <Icon name="chevron-down" size={20} color={theme.colors.grey2} />
                            </Flex>
                        </UnPressable>
                    </View>
                </View>

                {!!roomMeta && (
                    <UnText size={12} color={theme.colors.grey2} style={styles.roomMeta}>
                        {roomMeta}
                    </UnText>
                )}

                <UnText size={13} color={theme.colors.grey2}>
                    {`第 ${selection.week} 周${weekRange ? ` · ${weekRange}` : ""} · ${statusText}`}
                </UnText>

                {overview.loading && overview.snapshots.length === 0 && (
                    <View style={styles.loadingRow}>
                        <ActivityIndicator color={theme.colors.primary} />
                        <UnText size={13} color={theme.colors.grey2}>
                            正在加载缓存数据...
                        </UnText>
                    </View>
                )}

                {!!overview.error && (
                    <View style={[styles.errorBox, {borderColor: theme.colors.error}]}>
                        <UnText size={13} color={theme.colors.error}>
                            {`读取缓存失败：${overview.error}`}
                        </UnText>
                        <Flex justify="flex-end">
                            <Button size="sm" type="clear" title="重试" onPress={overview.reload} />
                        </Flex>
                    </View>
                )}

                <View style={styles.pagerContainer}>
                    <TimeScheduleView
                        pageView={pageView}
                        initialPage={selection.week - 1}
                        onPageChanged={handlePageChanged}
                        startDay={startDay}
                        showDate={ready}
                        showDayHighlight={ready}
                        showTimeSpanHighlight={false}
                        scheduleItems={scheduleItems}
                    />
                    {overlay && <WeekStatusOverlay {...overlay} />}
                </View>

                <View style={styles.legend}>
                    <View style={[styles.legendDot, {backgroundColor: theme.colors.success, opacity: 0.6}]} />
                    <UnText size={12} color={theme.colors.grey2}>
                        绿色=空闲，空白=有课/占用
                    </UnText>
                </View>
            </ScrollView>

            <RoomPickerSheet
                visible={roomSheetVisible}
                onClose={closeRoomPicker}
                year={selection.year}
                term={selection.term}
                selectedRoomId={selection.roomId}
                onSelect={item => setRoom(item.id)}
                onOpenCacheManager={() => {
                    closeRoomPicker();
                    openCacheManager();
                }}
            />
        </>
    );
}

const styles = StyleSheet.create({
    center: {
        flex: 1,
        alignItems: "center",
        justifyContent: "center",
    },
    container: {
        padding: 16,
        gap: 10,
    },
    filterRow: {
        flexDirection: "row",
        alignItems: "center",
        gap: 10,
    },
    filterLabel: {
        width: 48,
        textAlign: "right",
    },
    filterContent: {
        flex: 1,
    },
    roomButton: {
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 12,
        paddingVertical: 10,
    },
    roomLabel: {
        flexShrink: 1,
    },
    roomText: {
        flexShrink: 1,
    },
    roomMeta: {
        paddingLeft: 58,
        marginTop: -4,
    },
    loadingRow: {
        paddingVertical: 20,
        alignItems: "center",
        gap: 8,
    },
    errorBox: {
        borderWidth: 1,
        borderRadius: 8,
        padding: 12,
        gap: 6,
    },
    pagerContainer: {
        position: "relative",
    },
    legend: {
        flexDirection: "row",
        alignItems: "center",
        gap: 6,
        paddingHorizontal: 4,
        paddingTop: 4,
    },
    legendDot: {
        width: 12,
        height: 12,
        borderRadius: 3,
    },
});
