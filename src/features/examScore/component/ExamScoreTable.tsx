import React, {useMemo, useState} from "react";
import {ScrollView, StyleSheet, TouchableOpacity, View} from "react-native";
import {Text, useTheme} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";
import {ScoreRepo} from "@/features/examScore/type";
import {useUsualScore} from "@/features/examScore/hooks/useUsualScore.ts";

interface Props {
    data: ScoreRepo[];
    year: String;
    term: String;
}

export const calculatePoint = (score: number) => {
    if (isNaN(score)) return "N/A"; // 处理可能出现的等级制成绩
    if (score < 60) return "0";
    const gpa = (score - 50) / 10;
    return gpa.toFixed(2);
};

interface ScoreDetailRow {
    label: string;
    key?: keyof ScoreRepo;
    render?: (item: ScoreRepo) => React.ReactNode | string;
}

const scoreDetailRows: ScoreDetailRow[] = [
    {
        key: "upload_at",
        label: "发布时间",
    },
    {
        key: "credit",
        label: "学分",
    },
    {
        label: "绩点",
        render: item => calculatePoint(item.score),
    },
    {
        key: "teacher_name",
        label: "教师",
    },
];

export function ExamScoreTable(props: Props) {
    const [expandedId, setExpandedId] = useState<string | null>(null);
    const {theme} = useTheme();

    const {details, loadUsualScore} = useUsualScore();
    const handlePressRow = async (item: ScoreRepo) => {
        const newExpandedId = expandedId === item.id ? null : item.id;
        setExpandedId(newExpandedId);

        if (newExpandedId) {
            await loadUsualScore(item);
        }
    };

    const styles = useMemo(() => {
        return StyleSheet.create({
            detailItem: {
                paddingVertical: 8,
                paddingHorizontal: 12,
                marginVertical: 4,
            },
            detailItemLabel: {
                fontSize: 16,
                marginBottom: 2,
            },
            scoreItem: {
                flexDirection: "row",
                alignItems: "center", // 垂直居中
                paddingVertical: 12,
                paddingHorizontal: 16,
                borderColor: theme.colors.primary,
            },
            schoolYearText: {
                flex: 3,
                fontSize: 16,
                textAlign: "left",
                color: theme.colors.grey2,
            },
            examCourseName: {
                flex: 5,
                fontSize: 16,
                fontWeight: "600",
                textAlign: "left",
                paddingHorizontal: 8,
            },
            examScore: {
                flex: 2,
                fontSize: 18,
                fontWeight: "bold",
                textAlign: "right",
            },
            detailContainer: {
                borderTopColor: theme.colors.grey2,
                paddingHorizontal: 10,
                borderTopWidth: 0.1,
                paddingVertical: 12,
            },
            detailItemValue: {
                fontSize: 16,
                textAlign: "right",
            },
            cardContainer: {
                backgroundColor: theme.colors.background, // 或者 theme.colors.card
                borderRadius: 12,
                width: "100%",
                marginHorizontal: 12,
                marginVertical: 5,
            },
        });
    }, [theme]);

    return (
        <Flex>
            <ScrollView>
                <Flex direction="column">
                    <View style={styles.scoreItem}>
                        <Text style={styles.schoolYearText}>{"学年学期"}</Text>
                        <Text style={styles.examCourseName}>{"课程名称"}</Text>
                        <Text style={styles.examScore}>{"成绩"}</Text>
                    </View>
                    {props.data.map((item, index) => (
                        /* 外层 View 必须加 key，否则 React 会报警告 */
                        <ScoreRow
                            key={item.id}
                            item={item}
                            isExpanded={expandedId === item.id}
                            detailState={details[item.id]}
                            onPress={() => handlePressRow(item)}
                            styles={styles}
                        />
                    ))}
                </Flex>
            </ScrollView>
        </Flex>
    );
}

function ScoreRow({item, isExpanded, detailState, onPress, styles}) {
    return (
        <View style={styles.cardContainer} key={item.kcmc}>
            {/* 可点击的行 */}
            <TouchableOpacity activeOpacity={0.7} onPress={() => onPress(item)}>
                <View style={styles.scoreItem}>
                    <Text style={[styles.schoolYearText, item.score < 60 && {color: "red"}]}>
                        {item.term === 1 ? `${item.year} 秋` : `${item.year + 1} 春`}
                    </Text>
                    <Text style={[styles.examCourseName, item.score < 60 && {color: "red"}]}>{item.course_name}</Text>
                    <Text style={[styles.examScore, item.score < 60 && {color: "red"}]}>{item.score}</Text>
                </View>
            </TouchableOpacity>

            {isExpanded && (
                <View style={styles.detailContainer}>
                    {detailState?.status === "loading" && (
                        <Flex justify="space-between" style={styles.detailItem}>
                            <View style={{width: "55%"}}>
                                <Text style={styles.detailItemLabel} numberOfLines={1}>
                                    {"平时成绩"}
                                </Text>
                            </View>
                            <View>
                                <Text style={styles.detailItemLabel} numberOfLines={1}>
                                    {"正在加载中……"}
                                </Text>
                            </View>
                        </Flex>
                    )}
                    {detailState?.status === "error" && <Text style={{color: "red"}}>{detailState.error}</Text>}
                    {detailState?.status === "success" &&
                        detailState.data?.map((score, index) => {
                            return (
                                <Flex key={`index${index}`} justify="space-between" style={styles.detailItem}>
                                    <View style={{width: "55%"}}>
                                        <Text style={styles.detailItemLabel} numberOfLines={1}>
                                            {score.name || "暂无"}
                                            {score.ratio !== "N/A" && `（${score.ratio} %）`}
                                        </Text>
                                    </View>
                                    <View>
                                        <Text style={styles.detailItemLabel} numberOfLines={1}>
                                            {score.score || "暂无"}
                                        </Text>
                                    </View>
                                </Flex>
                            );
                        })}
                    {scoreDetailRows.map((row, detailIndex) => (
                        <Flex
                            justify="space-between"
                            key={`${item.jxb_id}-${row.key}-${detailIndex}`}
                            style={styles.detailItem}>
                            <View style={{width: "45%"}}>
                                <Text style={[styles.detailItemLabel, styles.detailItemLabel]}>{row.label}</Text>
                            </View>
                            <View style={{width: "55%"}}>
                                <Text style={[styles.detailItemLabel, styles.detailItemValue]}>
                                    {row.render ? row.render(item) : row.key ? item[row.key] : "暂无"}
                                </Text>
                            </View>
                        </Flex>
                    ))}
                </View>
            )}
        </View>
    );
}
