import {useCallback, useEffect, useMemo, useRef, useState} from "react";
import {ActivityIndicator, ScrollView, StyleSheet, ToastAndroid, View} from "react-native";
import {Button, Dialog, LinearProgress, useTheme} from "@rneui/themed";
import {Flex, UnCard, UnTermSelector, UnText} from "@/components/un-ui";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {WeekCacheRow} from "../components/WeekCacheRow";
import {useEmptyClassroomCache} from "../hooks/useEmptyClassroomCache";
import type {CacheStartResult, CacheTask} from "../stores/cacheRunnerStore";
import {useSelection, useSelectionInit, useSelectionTermSwitcher} from "../stores/selectionStore";
import {DAYS, MAX_WEEKS, PERIODS, SLOT_ROW_BYTES} from "../utils/constants";
import {estimateSizeBytes, formatBytes} from "../utils/format";
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

function taskPhaseText(task: CacheTask): string {
    if (task.phase === "auth") return "正在登录教务系统...";
    if (task.phase === "canceling") return "正在取消...";
    if (task.day > 0) return `第 ${task.day}/7 天 · 第 ${task.period}/13 节`;
    return "准备中...";
}

function taskProgressOf(task: CacheTask): number {
    const currentDayIncluded = task.completedDays.includes(task.day);
    const periodFraction = task.day > 0 && task.period > 0 && !currentDayIncluded ? (task.period - 1) / PERIODS : 0;
    return Math.max(0, Math.min(1, (task.completedDays.length + periodFraction) / DAYS));
}

/**
 * 作用：缓存管理页；按周缓存/续传/删除空闲教室数据，并展示全局任务与冷却状态。
 * 修改注意：
 * - 任务来自 runner store，可能属于其他学期，全局 banner 不受学期选择器影响；
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
    const {startDay, ready} = useStartDay(selection.year, selection.term);

    const scrollRef = useRef<ScrollView>(null);
    const rowOffsetsRef = useRef<Record<number, number>>({});
    const scrolledKeyRef = useRef("");
    const [startTarget, setStartTarget] = useState<number | null>(null);
    const [deleteTarget, setDeleteTarget] = useState<number | null>(null);
    const [deleting, setDeleting] = useState(false);

    const summary = useMemo(() => {
        let completeCount = 0;
        let partialCount = 0;
        let totalBytes = 0;

        for (const snapshot of cache.snapshots) {
            if (snapshot.complete || snapshot.completedDays >= DAYS) {
                completeCount += 1;
                totalBytes += estimateSizeBytes(snapshot.slotCount, snapshot.roomCount);
            } else if (snapshot.completedDays > 0) {
                partialCount += 1;
                totalBytes += SLOT_ROW_BYTES * snapshot.slotCount;
            }
        }

        return {completeCount, partialCount, totalBytes};
    }, [cache.snapshots]);

    const task = cache.task;
    const taskProgress = useMemo(() => (task ? taskProgressOf(task) : 0), [task]);
    const cooldownSeconds = Math.ceil(cache.cooldown.remainingMs / 1000);

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

    const startSnapshot = startTarget !== null ? cache.snapshotByWeek.get(startTarget) : undefined;
    const startCompletedDays = startSnapshot?.completedDays ?? 0;
    const startIsPartial = !!startSnapshot && startCompletedDays > 0 && !startSnapshot.complete;
    const startRemainingDays = Math.max(1, DAYS - startCompletedDays);
    const startMessage = startIsPartial
        ? `第 ${startTarget} 周已完成 ${startCompletedDays}/7 天，继续缓存剩余 ${startRemainingDays} 天（约 ${Math.ceil(
              (91 * startRemainingDays) / DAYS,
          )} 次请求）。\n建议 Wi-Fi 并保持应用在前台。`
        : "约 91 次请求 / gzip 约 1.3 MB（未压缩约 32 MB）/ 预计 1–2 分钟；若正方按 500 分页回退约 364 次。\n建议 Wi-Fi 并保持应用在前台。";

    const confirmStart = useCallback(async () => {
        const target = startTarget;
        if (target === null) return;

        setStartTarget(null);
        cache.clearError();

        const result = await cache.startWeek(target);
        if (!result.ok) {
            ToastAndroid.show(startErrorMessage(result), ToastAndroid.SHORT);
            return;
        }
        cache.reload();
    }, [cache, startTarget]);

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

    if (!selection.hydrated) {
        return (
            <View style={styles.center}>
                <ActivityIndicator color={theme.colors.primary} />
            </View>
        );
    }

    const legacyTerm = toLegacyTerm(selection.term);

    return (
        <View style={styles.screen}>
            <View style={styles.header}>
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
                    <Flex justify="space-between" align="center" gap={8}>
                        <UnText size={13} color={theme.colors.grey2}>
                            {`已缓存 ${summary.completeCount}/${MAX_WEEKS} 周`}
                        </UnText>
                        <UnText size={15} bold>
                            {`约 ${formatBytes(summary.totalBytes)}`}
                        </UnText>
                    </Flex>
                    {summary.partialCount > 0 && (
                        <UnText size={12} color={theme.colors.warning} style={styles.partialHint}>
                            {`未完成 ${summary.partialCount} 周`}
                        </UnText>
                    )}
                </UnCard>

                {cache.cooldown.blocked && (
                    <UnCard color="warning" style={styles.banner}>
                        <UnText size={12} color={theme.colors.warning}>
                            {`每分钟仅可缓存一周，还需 ${cooldownSeconds} 秒`}
                        </UnText>
                    </UnCard>
                )}

                {task && (
                    <UnCard color="primary" style={styles.banner} title="缓存进行中">
                        <UnText size={13}>
                            {`${task.year}-${task.year + 1} 学年 · ${
                                task.term === 1 ? "秋季" : "春季"
                            }学期 · 第 ${task.week} 周`}
                        </UnText>
                        <UnText size={12} color={theme.colors.grey2} style={styles.taskPhase}>
                            {taskPhaseText(task)}
                        </UnText>
                        <LinearProgress
                            value={taskProgress}
                            variant="determinate"
                            color={theme.colors.primary}
                            style={styles.progress}
                        />
                        <Flex justify="flex-end" style={styles.taskActions}>
                            <Button
                                size="sm"
                                type="clear"
                                title={task.phase === "canceling" ? "取消中..." : "取消"}
                                disabled={task.phase === "canceling"}
                                onPress={cache.cancel}
                            />
                        </Flex>
                    </UnCard>
                )}

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
                                onStart={() => setStartTarget(week)}
                                onCancel={cache.cancel}
                                onDelete={() => setDeleteTarget(week)}
                            />
                        </View>
                    );
                })}
            </ScrollView>

            <Dialog
                isVisible={startTarget !== null}
                onBackdropPress={() => setStartTarget(null)}
                overlayStyle={styles.dialog}>
                <Dialog.Title title={startTarget !== null ? `缓存第 ${startTarget} 周` : "缓存"} />
                <View style={styles.dialogBody}>
                    <UnText size={13} style={styles.dialogText}>
                        {startMessage}
                    </UnText>
                </View>
                <Dialog.Actions>
                    <Dialog.Button title="取消" type="clear" onPress={() => setStartTarget(null)} />
                    <Dialog.Button title={startIsPartial ? "继续缓存" : "开始缓存"} onPress={confirmStart} />
                </Dialog.Actions>
            </Dialog>

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
                        loading={deleting}
                        disabled={deleting}
                        onPress={confirmDelete}
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
    },
    partialHint: {
        marginTop: 4,
    },
    banner: {
        paddingHorizontal: 12,
        paddingVertical: 10,
    },
    taskPhase: {
        marginTop: 4,
    },
    progress: {
        height: 6,
        borderRadius: 3,
        marginTop: 8,
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
