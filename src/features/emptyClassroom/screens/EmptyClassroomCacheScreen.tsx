import {useCallback, useEffect, useMemo, useRef, useState} from "react";
import {ActivityIndicator, ScrollView, StyleSheet, ToastAndroid, View} from "react-native";
import {Button, Dialog, useTheme} from "@rneui/themed";
import {Flex, UnCard, UnTermSelector, UnText} from "@/components/un-ui";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {WeekCacheRow} from "../components/WeekCacheRow";
import {useEmptyClassroomCache} from "../hooks/useEmptyClassroomCache";
import {useEmptyClassroomStorage, type StorageClearTarget} from "../hooks/useEmptyClassroomStorage";
import type {CacheStartResult} from "../stores/cacheRunnerStore";
import {useSelection, useSelectionInit, useSelectionTermSwitcher} from "../stores/selectionStore";
import {DAYS, MAX_WEEKS} from "../utils/constants";
import {formatBytes} from "../utils/format";
import {toLegacyTerm} from "../utils/terms";

const WEEKS = Array.from({length: MAX_WEEKS}, (_, index) => index + 1);

/** 单周缓存启动失败时的唯一一条 Toast 文案。 */
function startErrorMessage(result: CacheStartResult): string {
    switch (result.reason) {
        case "busy":
            return "已有缓存任务正在进行，请等待当前任务结束";
        case "cooldown":
            return `每分钟仅可缓存一周，还需 ${Math.ceil((result.remainingMs ?? 0) / 1000)} 秒`;
        case "auth":
            return result.message ?? "登录教务失败，请检查账号或稍后重试";
        case "error":
            return result.message ?? "缓存失败，请稍后重试";
        default:
            return "无法开始缓存";
    }
}

type StorageMetricProps = {
    label: string;
    value: string;
    clearing: boolean;
    clearDisabled: boolean;
    refreshDisabled?: boolean;
    onClear: () => void;
    onRefresh?: () => void;
    refreshing?: boolean;
};

function StorageMetric(props: StorageMetricProps) {
    const {theme} = useTheme();

    return (
        <View style={styles.storageMetric}>
            <UnText size={12} color={theme.colors.grey2}>
                {props.label}
            </UnText>
            <UnText size={16} bold>
                {props.value}
            </UnText>
            <View style={styles.storageActions}>
                {props.onRefresh && (
                    <Button
                        size="sm"
                        type="clear"
                        title="刷新"
                        loading={props.refreshing}
                        disabled={props.refreshDisabled}
                        onPress={props.onRefresh}
                    />
                )}
                <Button
                    size="sm"
                    type="clear"
                    title="清除"
                    titleStyle={{color: theme.colors.error}}
                    loading={props.clearing}
                    loadingProps={{color: theme.colors.error}}
                    disabled={props.clearDisabled}
                    onPress={props.onClear}
                />
            </View>
        </View>
    );
}

/**
 * 作用：缓存管理页；按周缓存/续传/删除空闲教室数据，并展示全局任务与冷却状态。
 * 修改注意：
 * - startWeek 返回 ok 只代表任务结束，不代表 7 天已齐，因此不弹「缓存完成」；
 * - 删除不受冷却限制，但当前运行周由 hook 拒绝；
 * - 目标周 = selection.week，滚动仅作辅助，失败时保留高亮。
 */
export function EmptyClassroomCacheScreen() {
    useSelectionInit();
    const {theme} = useTheme();
    const selection = useSelection();
    const switchTerm = useSelectionTermSwitcher();
    const cache = useEmptyClassroomCache({year: selection.year, term: selection.term});
    const storage = useEmptyClassroomStorage();
    const {startDay, ready} = useStartDay(selection.year, selection.term);

    const scrollRef = useRef<ScrollView>(null);
    const rowOffsetsRef = useRef<Record<number, number>>({});
    const scrolledKeyRef = useRef("");
    const [deleteTarget, setDeleteTarget] = useState<number | null>(null);
    const [clearTarget, setClearTarget] = useState<StorageClearTarget | null>(null);
    const [deleting, setDeleting] = useState(false);

    const summary = useMemo(() => {
        let completeCount = 0;
        let partialCount = 0;

        for (const snapshot of cache.snapshots) {
            if (snapshot.complete || snapshot.completedDays >= DAYS) {
                completeCount += 1;
            } else if (snapshot.completedDays > 0) {
                partialCount += 1;
            }
        }

        return {completeCount, partialCount};
    }, [cache.snapshots]);

    const task = cache.task;

    const targetKey = `${selection.year}|${selection.term}|${selection.week}`;
    const scrollToTarget = useCallback(
        (fallbackY?: number) => {
            if (!selection.hydrated) return;
            if (scrolledKeyRef.current === targetKey) return;

            const y = fallbackY ?? rowOffsetsRef.current[selection.week];
            if (y === undefined) return;

            scrollRef.current?.scrollTo({y: Math.max(0, y - 8), animated: false});
            scrolledKeyRef.current = targetKey;
        },
        [selection.hydrated, selection.week, targetKey],
    );

    const handleRowLayout = useCallback(
        (week: number, y: number) => {
            rowOffsetsRef.current[week] = y;
            if (week === selection.week) scrollToTarget(y);
        },
        [selection.week, scrollToTarget],
    );

    useEffect(() => {
        if (!selection.hydrated) return;
        const timer = setTimeout(() => scrollToTarget(), 60);
        return () => clearTimeout(timer);
    }, [selection.hydrated, targetKey, scrollToTarget]);

    const startCache = useCallback(
        async (target: number) => {
            cache.clearError();

            const result = await cache.startWeek(target);
            if (!result.ok) {
                ToastAndroid.show(startErrorMessage(result), ToastAndroid.SHORT);
                return;
            }
            cache.reload();
        },
        [cache],
    );

    const confirmDelete = useCallback(async () => {
        const target = deleteTarget;
        if (target === null || deleting) return;

        setDeleting(true);
        const result = await cache.deleteWeek(target);
        setDeleting(false);
        setDeleteTarget(null);

        if (!result.ok) {
            ToastAndroid.show(
                result.reason === "running" ? "该周正在缓存，暂时无法删除" : (result.message ?? "删除失败，请稍后重试"),
                ToastAndroid.SHORT,
            );
            return;
        }
        ToastAndroid.show(`已删除第 ${target} 周缓存`, ToastAndroid.SHORT);
    }, [cache, deleteTarget, deleting]);

    const confirmClearStorage = useCallback(async () => {
        const target = clearTarget;
        if (target === null || storage.clearing !== null) return;

        setClearTarget(null);
        const result = target === "rooms" ? await storage.clearRooms() : await storage.clearWeeks();
        if (!result.ok) {
            ToastAndroid.show(result.message ?? "清除失败，请稍后重试", ToastAndroid.SHORT);
            return;
        }

        ToastAndroid.show(target === "rooms" ? "已清除教室和全部空闲情况" : "已清除全部空闲情况", ToastAndroid.SHORT);
    }, [clearTarget, storage]);

    if (!selection.hydrated) {
        return (
            <View style={styles.center}>
                <ActivityIndicator color={theme.colors.primary} />
            </View>
        );
    }

    const legacyTerm = toLegacyTerm(selection.term);
    const storageValueOf = (bytes: number | undefined) =>
        storage.usage ? `约 ${formatBytes(bytes ?? 0)}` : storage.loading ? "读取中..." : "—";
    const storageDisabled = task !== null || storage.clearing !== null;

    return (
        <View style={styles.screen}>
            <View style={styles.header}>
                <UnCard title="缓存数据存储占用" titleStyle={styles.storageTitle} style={styles.storageCard}>
                    <View style={styles.storageMetrics}>
                        <StorageMetric
                            label="教室"
                            value={storageValueOf(storage.usage?.roomsBytes)}
                            clearing={storage.clearing === "rooms"}
                            clearDisabled={storageDisabled}
                            refreshDisabled={storage.loading || storage.clearing !== null}
                            onRefresh={storage.refresh}
                            refreshing={storage.loading}
                            onClear={() => setClearTarget("rooms")}
                        />
                        <View style={[styles.storageDivider, {backgroundColor: theme.colors.grey4}]} />
                        <StorageMetric
                            label="空闲情况"
                            value={storageValueOf(storage.usage?.availabilityBytes)}
                            clearing={storage.clearing === "weeks"}
                            clearDisabled={storageDisabled}
                            onClear={() => setClearTarget("weeks")}
                        />
                    </View>
                    {storage.error && (
                        <UnText size={12} color={theme.colors.error} style={styles.storageError}>
                            {`读取占用失败：${storage.error}`}
                        </UnText>
                    )}
                </UnCard>

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

                <UnCard style={styles.summaryCard}>
                    <UnText size={13} color={theme.colors.grey2}>
                        {`已缓存 ${summary.completeCount}/${MAX_WEEKS} 周`}
                    </UnText>
                    {summary.partialCount > 0 && (
                        <UnText size={12} color={theme.colors.warning} style={styles.partialHint}>
                            {`未完成 ${summary.partialCount} 周`}
                        </UnText>
                    )}
                </UnCard>

                {cache.loading && (
                    <Flex justify="center" align="center" gap={6} style={styles.loadingRow}>
                        <ActivityIndicator color={theme.colors.primary} />
                        <UnText size={12} color={theme.colors.grey2}>
                            正在读取缓存列表...
                        </UnText>
                    </Flex>
                )}

                {!!cache.errorMessage && (
                    <UnCard color="error" style={styles.banner}>
                        <UnText size={12} color={theme.colors.error}>
                            {cache.errorMessage}
                        </UnText>
                        <Flex justify="flex-end" style={styles.taskActions}>
                            <Button size="sm" type="clear" title="重试" onPress={cache.reload} />
                        </Flex>
                    </UnCard>
                )}
            </View>

            <ScrollView
                ref={scrollRef}
                style={styles.list}
                contentContainerStyle={styles.listContent}
                onContentSizeChange={() => scrollToTarget()}>
                {WEEKS.map(week => {
                    const rowTask =
                        task && task.year === selection.year && task.term === selection.term && task.week === week
                            ? task
                            : null;
                    const rowError =
                        cache.error &&
                        cache.error.year === selection.year &&
                        cache.error.term === selection.term &&
                        cache.error.week === week
                            ? cache.error
                            : null;

                    return (
                        <View key={week} onLayout={event => handleRowLayout(week, event.nativeEvent.layout.y)}>
                            <WeekCacheRow
                                week={week}
                                snapshot={cache.snapshotByWeek.get(week) ?? null}
                                task={rowTask}
                                error={rowError}
                                cooldown={cache.cooldown}
                                targetHighlighted={week === selection.week}
                                disabled={task !== null}
                                startDay={ready ? startDay : undefined}
                                onStart={() => startCache(week)}
                                onCancel={cache.cancel}
                                onDelete={() => setDeleteTarget(week)}
                            />
                        </View>
                    );
                })}
            </ScrollView>

            <Dialog
                isVisible={deleteTarget !== null}
                onBackdropPress={() => {
                    if (!deleting) setDeleteTarget(null);
                }}
                overlayStyle={styles.dialog}>
                <Dialog.Title title={deleteTarget !== null ? `删除第 ${deleteTarget} 周缓存` : "删除缓存"} />
                <View style={styles.dialogBody}>
                    <UnText size={13} style={styles.dialogText}>
                        删除后本周的空闲数据需要重新缓存，确定删除吗？
                    </UnText>
                </View>
                <Dialog.Actions>
                    <Dialog.Button
                        title="取消"
                        type="clear"
                        disabled={deleting}
                        onPress={() => setDeleteTarget(null)}
                    />
                    <Dialog.Button
                        title={deleting ? "删除中..." : "删除"}
                        titleStyle={{color: theme.colors.error}}
                        loadingProps={{color: theme.colors.error}}
                        loading={deleting}
                        disabled={deleting}
                        onPress={confirmDelete}
                    />
                </Dialog.Actions>
            </Dialog>

            <Dialog
                isVisible={clearTarget !== null}
                onBackdropPress={() => {
                    if (storage.clearing === null) setClearTarget(null);
                }}
                overlayStyle={styles.dialog}>
                <Dialog.Title title={clearTarget === "rooms" ? "清除教室数据" : "清除空闲情况"} />
                <View style={styles.dialogBody}>
                    <UnText size={13} style={styles.dialogText}>
                        {clearTarget === "rooms"
                            ? "会清除全部教室和所有空闲情况，之后需要重新缓存。"
                            : "会清除所有空闲情况，教室信息会保留；之后需要重新缓存。"}
                    </UnText>
                </View>
                <Dialog.Actions>
                    <Dialog.Button
                        title="取消"
                        type="clear"
                        disabled={storage.clearing !== null}
                        onPress={() => setClearTarget(null)}
                    />
                    <Dialog.Button
                        title="清除"
                        titleStyle={{color: theme.colors.error}}
                        loadingProps={{color: theme.colors.error}}
                        loading={storage.clearing !== null}
                        disabled={storage.clearing !== null}
                        onPress={confirmClearStorage}
                    />
                </Dialog.Actions>
            </Dialog>
        </View>
    );
}

const styles = StyleSheet.create({
    center: {
        flex: 1,
        alignItems: "center",
        justifyContent: "center",
    },
    screen: {
        flex: 1,
    },
    header: {
        paddingHorizontal: 16,
        paddingTop: 12,
        gap: 10,
    },
    storageCard: {
        paddingHorizontal: 10,
        paddingBottom: 4,
    },
    storageTitle: {
        marginLeft: -8,
    },
    storageMetrics: {
        flexDirection: "row",
        alignItems: "stretch",
        gap: 10,
    },
    storageMetric: {
        flex: 1,
        gap: 2,
    },
    storageDivider: {
        width: StyleSheet.hairlineWidth,
    },
    storageActions: {
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "flex-end",
        marginTop: 2,
    },
    storageError: {
        marginTop: 2,
        marginBottom: 6,
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
    summaryCard: {
        paddingHorizontal: 12,
        paddingVertical: 10,
        marginBottom: 4,
    },
    partialHint: {
        marginTop: 4,
    },
    banner: {
        paddingHorizontal: 12,
        paddingVertical: 10,
    },
    taskActions: {
        marginTop: 6,
    },
    loadingRow: {
        paddingVertical: 4,
    },
    list: {
        flex: 1,
    },
    listContent: {
        paddingHorizontal: 16,
        paddingTop: 10,
        paddingBottom: 24,
        gap: 6,
    },
    dialog: {
        borderRadius: 8,
    },
    dialogBody: {
        paddingVertical: 8,
        paddingHorizontal: 4,
    },
    dialogText: {
        lineHeight: 20,
    },
});
