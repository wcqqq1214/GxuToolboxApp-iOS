import {useMemo} from "react";
import {ActivityIndicator, ScrollView, StyleSheet, Text, View} from "react-native";
import {useTheme} from "@rneui/themed";
import dayjs from "dayjs";
import {Icon} from "@/components/un-ui";
import {UnPressable} from "@/components/un-ui/UnPressable.tsx";
import {UnRefreshControl} from "@/components/un-ui/UnRefreshControl.tsx";
import {StatItem} from "../component/StatItem.tsx";
import {useElectiveProgress} from "../hooks/useElectiveProgress.ts";
import {formatProgressRequirement} from "../utils/progressDisplay.ts";

const STATUS_LABELS = {passed: "已及格", failed: "未及格", pending: "暂无成绩", voided: "成绩作废", review: "待核对"};

/** 展示后端校选课结果，旧页面保留在 LegacyElectiveStrategy 中供后续验证 */
export default function ElectiveProgressScreen() {
    const {theme} = useTheme();
    const {data, loading, refreshing, error, isCached, refresh} = useElectiveProgress();
    const styles = useMemo(
        () =>
            StyleSheet.create({
                content: {padding: 16, gap: 14},
                header: {flexDirection: "row", alignItems: "center", justifyContent: "space-between"},
                title: {fontSize: 18, fontWeight: "700", color: theme.colors.black, flex: 1},
                subtitle: {fontSize: 15, fontWeight: "600", color: theme.colors.black, marginBottom: 8},
                card: {padding: 16, borderRadius: 12, backgroundColor: theme.colors.white, gap: 8},
                text: {fontSize: 14, color: theme.colors.black},
                muted: {fontSize: 12, color: theme.colors.grey2},
                warning: {fontSize: 13, lineHeight: 20, color: theme.colors.warning},
                danger: {color: theme.colors.error},
                success: {color: theme.colors.success},
                divider: {
                    height: StyleSheet.hairlineWidth,
                    backgroundColor: theme.colors.greyOutline,
                    marginVertical: 6,
                },
                button: {paddingHorizontal: 12, paddingVertical: 8},
                buttonText: {fontSize: 14, color: theme.colors.primary},
                centered: {paddingVertical: 40, alignItems: "center", gap: 12},
                row: {flexDirection: "row", justifyContent: "space-between", alignItems: "center", gap: 12},
                course: {
                    paddingVertical: 12,
                    borderBottomWidth: StyleSheet.hairlineWidth,
                    borderBottomColor: theme.colors.greyOutline,
                    gap: 6,
                },
                courseName: {fontSize: 15, fontWeight: "500", color: theme.colors.black, flex: 1},
            }),
        [theme],
    );

    const qualified = data?.complete ? data.isQualified : null;

    return (
        <ScrollView
            contentContainerStyle={styles.content}
            refreshControl={<UnRefreshControl refreshing={refreshing} onRefresh={refresh} />}>
            <View style={styles.header}>
                <Text style={styles.title}>校选课修读进度</Text>
                <UnPressable
                    accessibilityRole="button"
                    accessibilityLabel="刷新校选课进度"
                    style={styles.button}
                    disabled={loading || refreshing}
                    onPress={refresh}>
                    <Text style={styles.buttonText}>{refreshing ? "查询中…" : "刷新"}</Text>
                </UnPressable>
            </View>
            {error && (
                <View style={styles.card}>
                    <Text style={[styles.text, styles.danger]}>{error}</Text>
                    <Text style={styles.muted}>
                        {data ? "已保留上次查询结果，可稍后刷新" : "请稍后刷新重试；如会话失效，请重新登录教务账号"}
                    </Text>
                </View>
            )}
            {loading && !data && (
                <View style={styles.centered}>
                    <ActivityIndicator color={theme.colors.primary} />
                    <Text style={styles.muted}>正在查询校选课修读进度…</Text>
                </View>
            )}
            {data && (
                <>
                    <View style={styles.card}>
                        <Text style={styles.subtitle}>{data.ruleName}</Text>
                        <Text style={styles.muted}>
                            {isCached ? "上次查询" : "更新于"} {dayjs(data.computedAt).format("YYYY-MM-DD HH:mm")}
                        </Text>
                        {!data.complete && (
                            <Text style={styles.warning}>
                                部分课程需要核对，以下学分仅包含已确认部分，暂无法判断总体是否达标
                            </Text>
                        )}
                        <View style={styles.divider} />
                        {data.requirements.map(item => (
                            <StatItem
                                key={item.key}
                                label={item.label}
                                value={formatProgressRequirement(item)}
                                passed={data.complete ? item.passed : null}
                            />
                        ))}
                        <View style={styles.divider} />
                        <View style={styles.row}>
                            <Text style={styles.text}>通识选修要求</Text>
                            <Text
                                style={[
                                    styles.subtitle,
                                    qualified === null ? styles.muted : qualified ? styles.success : styles.danger,
                                ]}>
                                {qualified === null ? "待核对" : qualified ? "达标" : "未达标"}
                            </Text>
                        </View>
                    </View>
                    {data.issues.length > 0 && (
                        <View style={styles.card}>
                            <Text style={styles.subtitle}>待核对课程</Text>
                            {data.issues.map((issue, index) => (
                                <Text key={`${issue.courseId}:${issue.classId}:${index}`} style={styles.warning}>
                                    {data.courses.find(course => course.courseId === issue.courseId)?.courseName ||
                                        "课程记录"}
                                    ：{issue.message}
                                </Text>
                            ))}
                        </View>
                    )}
                    <View style={styles.card}>
                        <Text style={styles.subtitle}>尚未确认完成的指定课程</Text>
                        {data.remainingRequired.length ? (
                            data.remainingRequired.map(name => (
                                <Text key={name} style={styles.text}>
                                    · {name}
                                </Text>
                            ))
                        ) : (
                            <Text style={[styles.text, styles.success]}>指定课程均已确认完成</Text>
                        )}
                    </View>
                    <View style={styles.card}>
                        <Text style={styles.subtitle}>课程成绩 · {data.courses.length} 门</Text>
                        {data.courses.map((course, index) => (
                            <View key={`${course.courseId}:${index}`} style={styles.course}>
                                <View style={styles.row}>
                                    {course.online === true && (
                                        <Icon name="cast-education" size={16} color={theme.colors.primary} />
                                    )}
                                    <Text style={styles.courseName}>{course.courseName || "未命名课程"}</Text>
                                    <Text
                                        style={[
                                            styles.text,
                                            course.status === "passed"
                                                ? styles.success
                                                : course.status === "failed"
                                                  ? styles.danger
                                                  : styles.muted,
                                        ]}>
                                        {course.score === null
                                            ? STATUS_LABELS[course.status]
                                            : `${course.score}分 · ${STATUS_LABELS[course.status]}`}
                                    </Text>
                                </View>
                                <Text style={styles.muted}>
                                    {course.credit === null ? "学分待核对" : `${course.credit} 学分`} ·{" "}
                                    {course.counted
                                        ? `已计入 ${course.countedCredits} 学分`
                                        : course.excludedReason || "暂未计入学分"}
                                </Text>
                                {course.teachers.length > 0 && (
                                    <Text style={styles.muted}>教师：{course.teachers.join("、")}</Text>
                                )}
                                {course.locations.length > 0 && (
                                    <Text style={styles.muted}>地点：{course.locations.join("、")}</Text>
                                )}
                            </View>
                        ))}
                        {!data.courses.length && <Text style={styles.muted}>暂无通识选修课记录</Text>}
                    </View>
                </>
            )}
        </ScrollView>
    );
}
