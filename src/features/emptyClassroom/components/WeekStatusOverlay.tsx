import {useMemo} from "react";
import {StyleSheet, View} from "react-native";
import {Button, LinearProgress, useTheme} from "@rneui/themed";
import {Flex, UnCard, UnText} from "@/components/un-ui";
import type {CacheTask} from "../stores/cacheRunnerStore";
import {DAYS, PERIODS} from "../utils/constants";

export type WeekStatusKind = "no-cache" | "week-uncached" | "incomplete" | "no-room" | "no-free" | "running";

export type WeekStatusOverlayProps = {
    /** 当前状态；null 时不渲染。 */
    kind: WeekStatusKind | null;
    /**
     * full：带暗色背景的居中完整覆盖层；
     * banner：贴在网格上方的窄条，不遮挡内容。
     * 缺省按状态选择：未缓存/未选教室用 full，未完成/无空闲/运行中用 banner。
     */
    mode?: "full" | "banner";
    week?: number;
    /** 已缓存天数（incomplete / running 状态使用）。 */
    completedDays?: number;
    /** running 状态的任务；只传与当前学期/周匹配的 task。 */
    task?: CacheTask | null;
    title?: string;
    message?: string;
    actionLabel?: string;
    onAction?: () => void;
    secondaryActionLabel?: string;
    onSecondaryAction?: () => void;
};

function defaultMode(kind: WeekStatusKind): "full" | "banner" {
    switch (kind) {
        case "incomplete":
        case "no-free":
        case "running":
            return "banner";
        default:
            return "full";
    }
}

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

function defaultMessage(kind: WeekStatusKind, completedDays: number): string {
    switch (kind) {
        case "no-cache":
            return "请先在缓存管理中缓存至少一周";
        case "week-uncached":
            return "缓存后才能查看该教室的空闲时间";
        case "incomplete":
            return `仅显示已缓存的天（${completedDays}/7）`;
        case "no-room":
            return "选择一间教室后查看本周的空闲时间";
        case "no-free":
            return "可以左右滑动查看其他周";
        case "running":
            return "缓存期间可以继续浏览已缓存的数据";
    }
}

function defaultActionLabel(kind: WeekStatusKind): string | undefined {
    switch (kind) {
        case "no-cache":
            return "去缓存管理";
        case "week-uncached":
            return "去缓存";
        case "incomplete":
            return "去缓存/继续";
        case "no-room":
            return "选择教室";
        case "running":
            return "查看详情";
        default:
            return undefined;
    }
}

/**
 * 作用：第一屏的状态覆盖层/横幅；只负责展示，不发起 repo 请求。
 * 修改注意：
 * - 根节点必须是 absoluteFill + pointerEvents="box-none"，暗色背景 pointerEvents="none"，
 *   提示卡片 pointerEvents="auto"，这样卡片外的区域仍可左右滑动 pager；
 * - full/banner 由调用方通过 mode 覆盖；running 且没有任何缓存天数时应由调用方传 full。
 */
export function WeekStatusOverlay(props: WeekStatusOverlayProps) {
    const {theme} = useTheme();
    const {
        kind,
        mode,
        week,
        task = null,
        title,
        message,
        actionLabel,
        onAction,
        secondaryActionLabel,
        onSecondaryAction,
    } = props;

    const completedDays = task?.completedDays.length ?? props.completedDays ?? 0;
    const resolvedMode = mode ?? (kind ? defaultMode(kind) : "full");

    const progress = useMemo(() => {
        if (!task) return 0;
        const currentDayIncluded = task.completedDays.includes(task.day);
        const periodFraction = task.day > 0 && task.period > 0 && !currentDayIncluded ? (task.period - 1) / PERIODS : 0;
        return Math.max(0, Math.min(1, (completedDays + periodFraction) / DAYS));
    }, [task, completedDays]);

    if (!kind) return null;

    const resolvedTitle = title ?? defaultTitle(kind, week ?? task?.week, completedDays);
    const resolvedMessage = message ?? defaultMessage(kind, completedDays);
    const resolvedActionLabel = actionLabel ?? defaultActionLabel(kind);

    const progressText =
        task?.phase === "auth"
            ? "正在登录教务系统..."
            : task?.phase === "canceling"
              ? "正在取消..."
              : task && task.day > 0
                ? `第 ${task.day}/7 天 · 第 ${task.period}/13 节`
                : "";

    const styles = StyleSheet.create({
        backdrop: {
            backgroundColor: "rgba(0, 0, 0, 0.35)",
        },
        fullContainer: {
            flex: 1,
            alignItems: "center",
            justifyContent: "center",
            padding: 24,
        },
        bannerContainer: {
            paddingHorizontal: 8,
            paddingTop: 8,
            alignItems: "center",
        },
        card: {
            width: "100%",
            maxWidth: 420,
        },
        message: {
            lineHeight: 20,
        },
        progress: {
            height: 6,
            borderRadius: 3,
            marginTop: 8,
        },
        progressText: {
            marginTop: 4,
        },
        actions: {
            marginTop: 10,
        },
    });

    return (
        <View style={StyleSheet.absoluteFill} pointerEvents="box-none">
            {resolvedMode === "full" && (
                <View style={[StyleSheet.absoluteFill, styles.backdrop]} pointerEvents="none" />
            )}
            <View
                style={resolvedMode === "full" ? styles.fullContainer : styles.bannerContainer}
                pointerEvents="box-none">
                <UnCard style={styles.card} title={resolvedTitle} pointerEvents="auto">
                    <UnText size={13} color={theme.colors.grey2} style={styles.message}>
                        {resolvedMessage}
                    </UnText>
                    {kind === "running" && (
                        <>
                            <LinearProgress
                                value={progress}
                                variant="determinate"
                                color={theme.colors.primary}
                                style={styles.progress}
                            />
                            <UnText size={12} color={theme.colors.grey2} style={styles.progressText}>
                                {progressText}
                                {completedDays > 0 ? ` · 已完成 ${completedDays}/7 天` : ""}
                            </UnText>
                        </>
                    )}
                    {((resolvedActionLabel && onAction) || (secondaryActionLabel && onSecondaryAction)) && (
                        <Flex gap={8} justify="flex-end" style={styles.actions}>
                            {secondaryActionLabel && onSecondaryAction && (
                                <Button
                                    size="sm"
                                    type="clear"
                                    title={secondaryActionLabel}
                                    onPress={onSecondaryAction}
                                />
                            )}
                            {resolvedActionLabel && onAction && (
                                <Button size="sm" title={resolvedActionLabel} onPress={onAction} />
                            )}
                        </Flex>
                    )}
                </UnCard>
            </View>
        </View>
    );
}
