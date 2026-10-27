import {useMemo} from "react";
import {StyleSheet, View} from "react-native";
import {Button, LinearProgress, useTheme} from "@rneui/themed";
import {UnText} from "@/components/un-ui";
import type {CacheTask} from "../stores/cacheRunnerStore";
import {DAYS, PERIODS} from "../utils/constants";

export type WeekStatusKind = "no-cache" | "week-uncached" | "incomplete" | "no-room" | "no-free" | "running";

export type WeekStatusOverlayProps = {
    /** 当前状态；null 时不渲染。 */
    kind: WeekStatusKind | null;
    week?: number;
    /** 已缓存天数（incomplete / running 状态使用）。 */
    completedDays?: number;
    /** running 状态的任务；只传与当前学期/周匹配的 task。 */
    task?: CacheTask | null;
    title?: string;
    actionLabel?: string;
    onAction?: () => void;
};

function defaultTitle(kind: WeekStatusKind, week: number | undefined, completedDays: number): string {
    const weekLabel = week ? `第 ${week} 周` : "当前周";
    switch (kind) {
        case "no-cache":
            return "本学期还没有缓存数据";
        case "week-uncached":
            return `${weekLabel}数据未缓存`;
        case "incomplete":
            return `缓存未完成 ${completedDays}/7 天`;
        case "no-room":
            return "请选择教室";
        case "no-free":
            return `${weekLabel}该教室无空闲`;
        case "running":
            return "正在缓存";
    }
}

function defaultActionLabel(kind: WeekStatusKind): string | undefined {
    switch (kind) {
        case "no-cache":
            return "去缓存管理";
        case "week-uncached":
            return "去缓存";
        case "incomplete":
            return "继续缓存";
        case "no-room":
            return "选择教室";
        case "running":
            return "查看详情";
        default:
            return undefined;
    }
}

/** 作用：课表前的紧凑缓存状态提示；只负责展示，不发起 repo 请求。 */
export function WeekStatusOverlay(props: WeekStatusOverlayProps) {
    const {theme} = useTheme();
    const {kind, week, task = null, title, actionLabel, onAction} = props;

    const completedDays = task?.completedDays.length ?? props.completedDays ?? 0;

    const progress = useMemo(() => {
        if (!task) return 0;
        const currentDayIncluded = task.completedDays.includes(task.day);
        const periodFraction = task.day > 0 && task.period > 0 && !currentDayIncluded ? (task.period - 1) / PERIODS : 0;
        return Math.max(0, Math.min(1, (completedDays + periodFraction) / DAYS));
    }, [task, completedDays]);

    if (!kind) return null;

    const resolvedTitle = title ?? defaultTitle(kind, week ?? task?.week, completedDays);
    const resolvedActionLabel = actionLabel ?? defaultActionLabel(kind);

    const phaseText =
        task?.phase === "auth"
            ? "正在登录教务系统..."
            : task?.phase === "canceling"
              ? "正在取消..."
              : task && task.day > 0
                ? `第 ${task.day}/7 天 · 第 ${task.period}/13 节`
                : task
                  ? "准备中..."
                  : "";
    const progressText = [phaseText, completedDays > 0 ? `已完成 ${completedDays}/7 天` : ""]
        .filter(Boolean)
        .join(" · ");

    return (
        <View style={styles.card}>
            <View style={styles.titleRow}>
                <UnText size={13} weight="bold" numberOfLines={1} style={styles.title}>
                    {resolvedTitle}
                </UnText>
                {resolvedActionLabel && onAction && (
                    <Button
                        size="sm"
                        type="clear"
                        title={resolvedActionLabel}
                        onPress={onAction}
                        style={styles.action}
                        titleStyle={styles.actionTitle}
                    />
                )}
            </View>
            {kind === "running" && (
                <>
                    <LinearProgress
                        value={progress}
                        variant="determinate"
                        color={theme.colors.primary}
                        style={styles.progress}
                    />
                    {!!progressText && (
                        <UnText size={11} color={theme.colors.grey2} numberOfLines={1} style={styles.progressText}>
                            {progressText}
                        </UnText>
                    )}
                </>
            )}
        </View>
    );
}

const styles = StyleSheet.create({
    card: {
        overflow: "hidden",
    },
    titleRow: {
        flexDirection: "row",
        alignItems: "center",
        gap: 6,
    },
    title: {
        flex: 1,
        minWidth: 0,
        lineHeight: 17,
    },
    action: {
        minHeight: 28,
        paddingHorizontal: 4,
        borderRadius: 14,
    },
    actionTitle: {
        fontSize: 14,
    },
    progress: {
        height: 4,
        marginTop: 5,
        borderRadius: 2,
    },
    progressText: {
        marginTop: 2,
        lineHeight: 14,
    },
});
