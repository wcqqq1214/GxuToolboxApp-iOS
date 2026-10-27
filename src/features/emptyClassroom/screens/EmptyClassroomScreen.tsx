import {useCallback, useEffect, useMemo, useRef, useState} from "react";
import {ActivityIndicator, ScrollView, StyleSheet, View} from "react-native";
import {useNavigation, type NavigationProp, type ParamListBase} from "@react-navigation/native";
import {Button, useTheme} from "@rneui/themed";
import {usePagerView} from "react-native-pager-view";
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

/**
 * 作用：空闲教室第一屏；选择学期/周/教室后从本地缓存渲染该教室的空闲时间段。
 * 修改注意：
 * - pager 只在 selection.week 被外部改变（切学期、初始化）时单向 setPage；
 *   用户滑动由 onPageChanged 写 store，禁止用 effect 读 pageView.activePage 覆盖 store；
 * - 周次状态、图例与缓存提示固定在课表前的页头中，避免内容变化推动课表；
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
            return {
                kind: "running",
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
                actionLabel: "去缓存管理",
                onAction: openCacheManager,
            };
        }

        if (!activeSnapshot || activeCompletedDays === 0) {
            return {
                kind: "week-uncached",
                week: selection.week,
                actionLabel: "去缓存",
                onAction: openCacheManager,
            };
        }

        if (activeCompletedDays < DAYS) {
            return {
                kind: "incomplete",
                week: selection.week,
                completedDays: activeCompletedDays,
                actionLabel: "继续缓存",
                onAction: openCacheManager,
            };
        }

        if (!selection.roomId) {
            return {
                kind: "no-room",
                actionLabel: "选择教室",
                onAction: openRoomPicker,
            };
        }

        if (weekLoaded && freeCount === 0) {
            return {kind: "no-free", week: selection.week, title: "本周该教室无空闲"};
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

        switch (overlay?.kind) {
            case "no-cache":
                return "请先在缓存管理中缓存至少一周";
            case "week-uncached":
                return "缓存后才能查看该教室的空闲时间";
            case "incomplete":
                return `仅显示已缓存的天（${overlay.completedDays ?? activeCompletedDays}/7）`;
            case "no-room":
                return "选择一间教室后查看本周的空闲时间";
            case "no-free":
                return "可以左右滑动查看其他周";
            case "running":
                return "缓存期间可以继续浏览已缓存的数据";
        }

        if (!weekLoaded) return "加载中";
        if (!selection.roomId) return "未选择教室";
        return `空闲 ${freeCount} 节`;
    }, [overview.loading, overview.error, overlay, weekLoaded, selection.roomId, freeCount]);

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
    const room = overview.room;
    const roomLabel = room ? `${room.building} · ${room.name}` : selection.roomId ? "正在加载教室信息..." : "选择教室";
    const roomMeta = room
        ? [room.placeType, room.seatCount !== null ? `${room.seatCount} 座位` : ""].filter(Boolean).join(" · ")
        : "";
    const showHeaderBackground =
        !!overview.error || (overview.loading && overview.snapshots.length === 0) || overlay !== null;

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
                            <Flex justify="space-between" align="flex-start" gap={8}>
                                <Flex inline align="flex-start" gap={6} style={styles.roomLabel}>
                                    <Icon name="door" size={18} color={theme.colors.grey2} />
                                    <UnText size={15} style={styles.roomText}>
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

                <View
                    style={[
                        styles.scheduleHeader,
                        showHeaderBackground && styles.scheduleHeaderWithNotice,
                        showHeaderBackground && {
                            backgroundColor: theme.colors.grey5,
                            borderColor: theme.colors.grey4,
                        },
                    ]}>
                    <UnText size={13} color={theme.colors.grey2} style={styles.weekStatusText}>
                        {`第 ${selection.week} 周 · ${statusText}`}
                    </UnText>
                    <View style={styles.legend}>
                        <View style={[styles.legendDot, {backgroundColor: theme.colors.success, opacity: 0.6}]} />
                        <UnText size={12} color={theme.colors.grey2} numberOfLines={2}>
                            绿色=空闲，空白=有课/占用
                        </UnText>
                    </View>

                    {showHeaderBackground && (
                        <View style={styles.noticeSlot}>
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
                                    <UnText size={13} color={theme.colors.error} style={styles.errorText}>
                                        {`读取缓存失败：${overview.error}`}
                                    </UnText>
                                    <Button size="sm" type="clear" title="重试" onPress={overview.reload} />
                                </View>
                            )}

                            {overlay && <WeekStatusOverlay {...overlay} />}
                        </View>
                    )}
                </View>

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
    scheduleHeader: {
        gap: 4,
        paddingHorizontal: 4,
        paddingVertical: 4,
    },
    scheduleHeaderWithNotice: {
        padding: 8,
        borderWidth: 1,
        borderRadius: 8,
    },
    weekStatusText: {
        lineHeight: 17,
    },
    noticeSlot: {
        minHeight: 0,
    },
    loadingRow: {
        minHeight: 32,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "center",
        gap: 8,
    },
    errorBox: {
        flex: 1,
        flexDirection: "row",
        alignItems: "center",
        borderWidth: 1,
        borderRadius: 8,
        paddingHorizontal: 10,
        gap: 8,
    },
    errorText: {
        flex: 1,
        lineHeight: 17,
    },
    pagerContainer: {
        position: "relative",
    },
    legend: {
        flexDirection: "row",
        alignItems: "center",
        gap: 6,
        flexShrink: 0,
    },
    legendDot: {
        width: 12,
        height: 12,
        borderRadius: 3,
    },
});
