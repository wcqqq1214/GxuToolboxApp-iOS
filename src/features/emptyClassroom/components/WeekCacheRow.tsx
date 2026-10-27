import {useMemo} from "react";
import {StyleSheet, View} from "react-native";
import moment from "moment/moment";
import {Button, LinearProgress, useTheme} from "@rneui/themed";
import {Color} from "@/shared/color.ts";
import {Flex, UnText} from "@/components/un-ui";
import type {CacheTask, CacheTaskError} from "../stores/cacheRunnerStore";
import type {WeekSnapshot} from "../type";
import {DAYS, PERIODS} from "../utils/constants";
import {estimateSizeBytes, formatBytes, formatCacheTime} from "../utils/format";
import type {CooldownState} from "../hooks/useCooldown";

export type WeekCacheRowProps = {
    /** 第几周，1–20。 */
    week: number;
    /** 该周快照；null/undefined 表示未缓存。 */
    snapshot?: WeekSnapshot | null;
    /** 该周正在运行的任务；调用方只传匹配 year/term/week 的 task。 */
    task?: CacheTask | null;
    /** 该周最近一次失败；只传匹配 year/term/week 的错误。 */
    error?: CacheTaskError | null;
    /** useCooldown 的结果；开始/继续/重试按钮受它限制。 */
    cooldown: CooldownState;
    /** 从第一屏「去缓存」进入时高亮目标周。 */
    targetHighlighted?: boolean;
    /** 其他周正在运行等原因禁用开始按钮。 */
    disabled?: boolean;
    /** 学期第一天，用于显示 "9.7–9.13"；缺失时只显示周次。 */
    startDay?: moment.MomentInput;
    onStart: () => void;
    onCancel: () => void;
    onDelete: () => void;
};

function dateRangeOf(startDay: moment.MomentInput | undefined, week: number): string {
    if (startDay === undefined || startDay === null) return "";
    const begin = moment(startDay);
    if (!begin.isValid()) return "";

    const start = begin.clone().add((week - 1) * 7, "days");
    const end = start.clone().add(6, "days");
    return `${start.month() + 1}.${start.date()}–${end.month() + 1}.${end.date()}`;
}

function runningDetailOf(task: CacheTask): string {
    if (task.phase === "auth") return "正在登录教务系统...";
    if (task.phase === "canceling") return "正在取消...";
    if (task.day <= 0) return "准备中...";
    return `第 ${Math.max(1, task.day)}/7 天 · 第 ${Math.max(1, task.period)}/13 节`;
}

/**
 * 作用：缓存管理页的单周行；纯展示，不调用 repo。
 * 状态优先级：running > complete > partial > none。
 * 修改注意：
 * - 当前运行周不显示删除（由 hook 拒绝删除）；
 * - 冷却只禁用开始/继续/重试，不影响删除；
 * - 未缓存周不展示任何体积预估，只有缓存成功/未完成且已有数据时才显示大小；
 * - 未完成周即使没有可展示的大小也要保留状态块；
 * - 错误只在本行内联展示，不弹 Toast。
 */
export function WeekCacheRow(props: WeekCacheRowProps) {
    const {theme} = useTheme();
    const {
        week,
        snapshot,
        error,
        cooldown,
        targetHighlighted = false,
        disabled = false,
        startDay,
        onStart,
        onCancel,
        onDelete,
    } = props;
    const runningTask = props.task && props.task.week === week ? props.task : null;
    const rowError = error && error.week === week ? error : null;

    const completedDays = snapshot?.completedDays ?? 0;
    const complete = !runningTask && (snapshot?.complete === true || completedDays >= DAYS);
    const partial = !runningTask && !complete && completedDays > 0;
    const slotCount = snapshot?.slotCount ?? 0;

    const weekRange = useMemo(() => dateRangeOf(startDay, week), [startDay, week]);

    const progress = useMemo(() => {
        if (!runningTask) return 0;
        const currentDayIncluded = runningTask.completedDays.includes(runningTask.day);
        const periodFraction =
            runningTask.day > 0 && runningTask.period > 0 && !currentDayIncluded
                ? (runningTask.period - 1) / PERIODS
                : 0;
        return Math.max(0, Math.min(1, (runningTask.completedDays.length + periodFraction) / DAYS));
    }, [runningTask]);

    const cooldownSeconds = Math.ceil(cooldown.remainingMs / 1000);
    const startDisabled = disabled || cooldown.blocked;
    const startLabel = cooldown.blocked ? `冷却中 ${cooldownSeconds}s` : rowError ? "重试" : "缓存";

    const statusText = runningTask
        ? "正在缓存"
        : complete
          ? `已缓存 · 约 ${formatBytes(estimateSizeBytes(slotCount, snapshot?.roomCount ?? 0))}${
                snapshot?.fetchedAt ? ` · ${formatCacheTime(snapshot.fetchedAt)}` : ""
            }`
          : partial
            ? `未完成 ${completedDays}/7 天${slotCount > 0 ? ` · 约 ${formatBytes(estimateSizeBytes(slotCount, 0))}` : ""}`
            : "未缓存";

    const progressText = runningTask ? runningDetailOf(runningTask) : "";

    const styles = useMemo(
        () =>
            StyleSheet.create({
                row: {
                    borderRadius: 8,
                    borderWidth: 1,
                    borderColor: targetHighlighted ? theme.colors.primary : theme.colors.grey4,
                    backgroundColor: targetHighlighted
                        ? Color(theme.colors.primary).setAlpha(theme.mode === "light" ? 0.08 : 0.16).rgbaString
                        : theme.mode === "light"
                          ? theme.colors.white
                          : theme.colors.grey5,
                    paddingHorizontal: 12,
                    paddingVertical: 8,
                    gap: 4,
                },
                title: {
                    flexShrink: 1,
                },
                status: {
                    lineHeight: 16,
                },
                progressTrack: {
                    flex: 1,
                },
                progress: {
                    height: 6,
                    borderRadius: 3,
                },
                error: {
                    lineHeight: 16,
                },
            }),
        [targetHighlighted, theme],
    );

    return (
        <View style={styles.row}>
            <Flex justify="space-between" align="center" gap={8}>
                <UnText size={15} bold numberOfLines={1} style={styles.title}>
                    {`第 ${week} 周`}
                    {weekRange ? ` · ${weekRange}` : ""}
                </UnText>

                <Flex inline gap={2} align="center">
                    {runningTask ? (
                        <Button
                            size="sm"
                            type="clear"
                            title={runningTask.phase === "canceling" ? "取消中..." : "取消"}
                            disabled={runningTask.phase === "canceling"}
                            onPress={onCancel}
                        />
                    ) : (
                        <>
                            {(complete || partial) && (
                                <Button
                                    size="sm"
                                    type="clear"
                                    title="删除"
                                    titleStyle={{color: theme.colors.error}}
                                    onPress={onDelete}
                                />
                            )}
                            {!complete && (
                                <Button
                                    size="sm"
                                    title={
                                        partial
                                            ? cooldown.blocked
                                                ? `冷却中 ${cooldownSeconds}s`
                                                : "继续"
                                            : startLabel
                                    }
                                    disabled={startDisabled}
                                    onPress={onStart}
                                />
                            )}
                        </>
                    )}
                </Flex>
            </Flex>

            <UnText size={12} color={theme.colors.grey2} style={styles.status}>
                {statusText}
            </UnText>

            {runningTask && (
                <Flex gap={8} align="center">
                    <View style={styles.progressTrack}>
                        <LinearProgress
                            value={progress}
                            variant="determinate"
                            color={theme.colors.primary}
                            style={styles.progress}
                        />
                    </View>
                    <UnText size={11} color={theme.colors.grey2} numberOfLines={1}>
                        {progressText}
                    </UnText>
                </Flex>
            )}

            {rowError && (
                <UnText size={12} color={theme.colors.error} style={styles.error}>
                    {rowError.message}
                </UnText>
            )}
        </View>
    );
}
