import {useEffect, useMemo, useState} from "react";
import {electiveAPI} from "@/features/electiveStrategy/api";
import {ActivityIndicator, ScrollView, StyleSheet, Text, View} from "react-native";
import {Flex, Icon} from "@/components/un-ui";
import {useTheme} from "@rneui/themed";
import {CourseList} from "@/features/electiveStrategy/api/schema.ts";
import {getStrategy} from "@/features/electiveStrategy/utils";
import {StatItem} from "@/features/electiveStrategy/component/StatItem.tsx";
import {userProfile} from "@/core/user/profile.ts";
import {examApi} from "@/js/jw/exam.ts";

export default function ElectiveStrategy() {
    const {theme} = useTheme();

    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    // 唯一的数据源
    const [courses, setCourses] = useState<CourseList[]>([]);
    const [score, setScore] = useState<any[]>([]);
    const [userGrade, setUserGrade] = useState<number>(2025);

    useEffect(() => {
        const init = async () => {
            try {
                setLoading(true);
                setError(null);

                // 并行获取课程、成绩和用户信息
                const coursePromise = electiveAPI
                    .getCourses()
                    .then(r => r!.items.filter((i: any) => i.selectionType === "通识选修课"));
                const infoPromise = userProfile.loadUserInfo();

                // 只要已修完，出成绩，并且及格了的科目
                const scorePromise = examApi
                    .getExamScore("", "", 1, 1000)
                    .then(r => r!.items.filter((i: any) => Number(i.cj) >= 60));

                const [fetchedCourses, userInfo, score] = await Promise.all([coursePromise, infoPromise, scorePromise]);

                setScore(
                    score.map((i: any) => ({
                        courseName: i.kcmc,
                        score: Number(i.cj),
                    })),
                );

                setCourses(fetchedCourses);

                if (userInfo && userInfo.grade) {
                    setUserGrade(userInfo.grade);
                } else {
                    setUserGrade(2025);
                }
            } catch (e) {
                setError("数据加载失败，请稍后重试。");
            } finally {
                setLoading(false);
            }
        };

        init();
    }, []);

    const styles = useMemo(() => style(theme), []);
    const strategy = useMemo(() => getStrategy(userGrade), [userGrade]);
    const stats = useMemo(() => {
        // 只保留统计已及格的课程
        const passedCourses = courses.filter(c => score.some((s: any) => s.courseName === c.courseName));
        return strategy!.calculate(passedCourses);
    }, [courses, strategy, score]);

    if (loading) {
        return (
            <View style={styles.centered}>
                <ActivityIndicator size="large" />
            </View>
        );
    }

    if (error) {
        return (
            <View style={styles.centered}>
                <Text>{error}</Text>
            </View>
        );
    }

    if (!strategy || !stats) {
        return (
            <View style={styles.centered}>
                <Text>无法确定培养方案。</Text>
            </View>
        );
    }

    return (
        <ScrollView style={styles.container}>
            <View style={styles.card}>
                <Flex>
                    <Text style={styles.title}>{strategy.name}</Text>
                </Flex>
                <View style={styles.divider} />
                {strategy.ui.requirements.map(req => (
                    <StatItem key={req.key} label={req.label} value={req.format(stats)} passed={req.passed(stats)} />
                ))}

                <View style={styles.divider} />

                <Text style={styles.subtitle}>待完成必修课</Text>
                {stats.remainingRequired.length > 0 ? (
                    stats.remainingRequired.map(course => (
                        <Text key={course} style={styles.requiredItem}>
                            - {course}
                        </Text>
                    ))
                ) : (
                    <Text style={[styles.requiredItem, styles.textSuccess]}>全部完成</Text>
                )}

                <View style={styles.divider} />

                <View style={styles.conclusion}>
                    <Text style={styles.conclusionText}>毕业资格</Text>
                    <Text style={[styles.conclusionStatus, stats.isQualified ? styles.textSuccess : styles.textDanger]}>
                        {stats.isQualified ? "达标" : "不达标"}
                    </Text>
                </View>
            </View>

            <View style={styles.card}>
                <View>
                    <Text style={styles.title}>课程成绩</Text>
                    <Text style={[styles.title, {fontSize: 12}]}>网课使用图标标记</Text>
                </View>
                <View style={styles.divider} />
                {courses.map((c, index) => {
                    const scoreRecord = score.find((s: any) => s.courseName === c.courseName);
                    const isPassed = scoreRecord && scoreRecord.score >= 60;

                    return (
                        <View key={index} style={styles.courseRow}>
                            <View style={styles.courseInfo}>
                                <Flex direction="row" align="center" gap={6}>
                                    {(c.belongTo.includes("网络") || c.teacher === "网络教师") && (
                                        <Icon name="cast-education" size={16} color={theme.colors.primary} />
                                    )}
                                    <Text style={styles.courseName}>{c.courseName}</Text>
                                </Flex>
                                <Text style={styles.courseMeta}>
                                    {c.system} · 学分 {c.credit}
                                </Text>
                            </View>
                            <View style={styles.scoreBadge}>
                                {scoreRecord ? (
                                    <Text style={[styles.scoreText, isPassed ? styles.textSuccess : styles.textDanger]}>
                                        {scoreRecord.score}分
                                    </Text>
                                ) : (
                                    <Text style={styles.scorePending}>已挂科或未出成绩</Text>
                                )}
                            </View>
                        </View>
                    );
                })}
            </View>
        </ScrollView>
    );
}

const style = (theme: any) =>
    StyleSheet.create({
        container: {
            flex: 1,
            backgroundColor: theme.backgroundColor,
            padding: 10,
        },
        card: {
            backgroundColor: theme.backgroundColor,
            padding: 16,
            marginBottom: 16,
        },
        centered: {
            flex: 1,
            justifyContent: "center",
            alignItems: "center",
        },
        title: {
            fontSize: 20,
            color: theme.colors.primary,
            paddingRight: 20,
        },
        subtitle: {
            fontSize: 16,
            fontWeight: "600",
            color: theme.colors.primary,
            marginTop: 8,
            marginBottom: 4,
        },
        divider: {
            height: 1,
            backgroundColor: theme.colors.primary,
            marginVertical: 12,
        },
        statItem: {
            flexDirection: "row",
            justifyContent: "space-between",
            alignItems: "center",
            paddingVertical: 6,
        },
        statLabel: {
            fontSize: 15,
            color: theme.colors.black,
        },
        statValue: {
            fontSize: 15,
            fontWeight: "bold",
        },
        requiredItem: {
            fontSize: 14,
            color: "#d9534f",
            marginLeft: 10,
            lineHeight: 22,
        },
        courseItem: {
            fontSize: 14,
            color: "#666",
            paddingVertical: 4,
        },
        conclusion: {
            flexDirection: "row",
            justifyContent: "space-between",
            alignItems: "center",
            marginTop: 8,
        },
        conclusionText: {
            fontSize: 16,
            fontWeight: "bold",
            color: theme.colors.primary,
        },
        conclusionStatus: {
            fontSize: 16,
            fontWeight: "bold",
        },
        textSuccess: {
            color: "#5cb85c", // 绿色
        },
        textDanger: {
            color: "#d9534f", // 红色
        },
        courseRow: {
            flexDirection: "row",
            justifyContent: "space-between",
            alignItems: "center",
            paddingVertical: 10,
            borderBottomWidth: StyleSheet.hairlineWidth,
            borderBottomColor: theme.colors.greyOutline,
        },
        courseInfo: {
            flex: 1,
        },
        courseName: {
            fontSize: 15,
            fontWeight: "500",
            color: theme.colors.black,
            marginBottom: 2,
        },
        courseMeta: {
            fontSize: 12,
            color: theme.colors.grey2,
        },
        scoreBadge: {
            minWidth: 50,
            alignItems: "flex-end",
        },
        scoreText: {
            fontSize: 15,
            fontWeight: "bold",
        },
        scorePending: {
            fontSize: 13,
            color: theme.colors.grey3,
        },
    });
