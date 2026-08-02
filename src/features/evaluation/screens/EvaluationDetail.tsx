import {ActivityIndicator, ScrollView, StyleSheet, TouchableOpacity, View} from "react-native";
import {Button, Text, useTheme} from "@rneui/themed";
import {useCallback, useEffect, useLayoutEffect, useReducer, useRef} from "react";
import {parseEvaluationHTML} from "@/features/evaluation/utils/parser.ts";
import {EvaCategory} from "@/features/evaluation/components/EvaCategory.tsx";
import {evaluationApi} from "@/features/evaluation/api";
import {evaluationReducer, initialState} from "@/features/evaluation/store/EvaReducer.ts";
import {createDefaultReq, fillReq} from "@/features/evaluation/utils/reqBuilder.ts";
import {EvaTeacherList} from "@/features/evaluation/types/schema/TeacherList.ts";

export function EvaluationDetail({navigation, route}) {
    const scrollViewRef = useRef<ScrollView>(null);
    const [state, dispatch] = useReducer(evaluationReducer, initialState);
    const {loading, error, teachers, comment, ids, selected, defaultReq} = state;
    const {theme} = useTheme();

    const {evaluationItem} = route.params as {evaluationItem: EvaTeacherList};

    const onSelect = useCallback((catIdx: number, itIdx: number, optIdx: number) => {
        dispatch({type: "SELECT_OPTION", payload: {catIdx, itIdx, optIdx}});
    }, []);

    useLayoutEffect(() => {
        navigation.setOptions({
            title: `${evaluationItem.teacherName}（${evaluationItem.courseName}）`,
        });
    }, [navigation, evaluationItem]);

    const styles = StyleSheet.create({
        container: {
            paddingHorizontal: 16,
            paddingTop: 20,
            paddingBottom: 40,
        },
        card: {
            backgroundColor: theme.colors.background,
            padding: 20,
            marginBottom: 16,
            borderRadius: 12,
            shadowColor: "#000",
            shadowOffset: {width: 0, height: 2},
            shadowOpacity: 0.05,
        },
        header: {
            fontSize: 18,
            fontWeight: "700",
            color: theme.colors.black,
            marginBottom: 16,
        },
        statusBadge: {
            fontSize: 13,
            fontWeight: "600",
            color: theme.colors.primary,
        },
        commentCard: {
            backgroundColor: theme.colors.background,
            borderRadius: 12,
            padding: 20,
            marginBottom: 16,
        },
        commentLabel: {
            fontSize: 15,
            fontWeight: "500",
            color: theme.colors.grey0,
            marginBottom: 12,
        },
        commentInput: {
            paddingVertical: 12,
            paddingHorizontal: 14,
            backgroundColor: theme.mode === "dark" ? "rgba(255,255,255,0.05)" : "#fafafa",
            borderRadius: 8,
            minHeight: 60,
            justifyContent: "center",
        },
        commentPlaceholder: {
            color: theme.colors.grey3,
            fontSize: 14,
        },
        commentText: {
            color: theme.colors.black,
            fontSize: 14,
            lineHeight: 20,
        },
        actionRow: {
            flexDirection: "row",
            gap: 12,
            marginBottom: 16,
        },
        actionButton: {
            flex: 1,
            backgroundColor: theme.colors.primary,
            borderRadius: 12,
            paddingVertical: 14,
            alignItems: "center",
            justifyContent: "center",
        },
        actionButtonSecondary: {
            backgroundColor: theme.mode === "dark" ? "rgba(255,255,255,0.08)" : "#f0f0f0",
        },
        actionButtonText: {
            color: theme.colors.white,
            fontSize: 15,
            fontWeight: "700",
        },
        actionButtonTextSecondary: {
            color: theme.colors.primary,
        },
        submitButton: {
            backgroundColor: theme.colors.primary,
            borderRadius: 12,
            paddingVertical: 16,
            alignItems: "center",
            justifyContent: "center",
        },
        submitButtonText: {
            color: theme.colors.white,
            fontSize: 16,
            fontWeight: "700",
        },
    });

    const FastSubmit = () => {
        const goodSelected = {
            0: {
                0: {0: 0, 1: 0, 2: 0, 3: 0},
                1: {0: 0, 1: 0, 2: 0},
                2: {0: 0, 1: 0, 2: 1},
                3: {0: 0, 1: 0, 2: 0},
                4: {0: 0, 1: 0, 2: 0},
            },
        };
        dispatch({type: "SET_SELECTED", payload: goodSelected});
        const defaultComment =
            "老师专业功底深厚，治学态度严谨。在教学中，您逻辑清晰，重点突出，" +
            "善于运用启发式教学引导我们独立思考，将理论与实践紧密结合。课堂富有感染力，" +
            "不仅传授了我们前沿的知识，更点燃了我们对该领域的探索热情。是我们学术道路上当之无愧的引路人。" +
            "老师的悉心栽培令我们受益匪浅！";
        dispatch({type: "SET_COMMENT", payload: defaultComment});
        handleSave(goodSelected, defaultComment);
    };
    /** 点击提交按钮触发提交
     * @param submitSelected 提交的选项
     * @param submitComment 提交的评语
     *
     * @description 两个参数都是可选项，如不填则提交屏幕上的参数
     *
     * 一般在适用快速评价（如一键评价、一键清空等）时传入特定的参数
     * */
    const handleSave = async (submitSelected = selected, submitComment: string = comment) => {
        console.log("start-saving");

        const reqToSend = fillReq(defaultReq, submitSelected, submitComment, ids);

        if (reqToSend.modelList[0]) {
            reqToSend.modelList[0].py = submitComment;
        }

        const res = await evaluationApi.handleEvaResult(defaultReq, reqToSend);
        console.log(res);
        dispatch({type: "SET_SELECTED", payload: submitSelected});
        init();
    };

    // init，一点开页面就调用
    async function init() {
        dispatch({type: "FETCH_START"});
        try {
            const HtmlText = await evaluationApi.getEvaluationDetail(
                evaluationItem.securityToken,
                evaluationItem.teachingClassId,
                evaluationItem.courseId,
                evaluationItem.courseTypeCode,
                evaluationItem.rubricId,
            );
            const {idObj, teachers, selected} = parseEvaluationHTML(HtmlText);

            const defReq = createDefaultReq(evaluationItem, idObj);

            dispatch({
                type: "FETCH_SUCCESS",
                payload: {teachers, selected: selected || {}, ids: idObj, defaultReq: defReq},
            });
        } catch (e: any) {
            dispatch({type: "FETCH_ERROR", payload: e.message});
        }
    }

    useEffect(() => {
        init();
    }, []);

    if (loading) {
        return (
            <View style={{flex: 1, justifyContent: "center", alignItems: "center"}}>
                <ActivityIndicator size="large" color={theme.colors.primary} />
            </View>
        );
    }

    if (error) {
        return (
            <View style={{flex: 1, justifyContent: "center", alignItems: "center"}}>
                <Text style={{color: theme.colors.error}}>评教页面加载失败: {error}</Text>
                <Button onPress={init}>重试</Button>
            </View>
        );
    }

    return (
        <ScrollView ref={scrollViewRef} contentContainerStyle={styles.container}>
            <View style={styles.actionRow}>
                <TouchableOpacity onPress={FastSubmit} style={[styles.actionButton, styles.actionButtonSecondary]}>
                    <Text style={[styles.actionButtonText, styles.actionButtonTextSecondary]}>应用示例</Text>
                </TouchableOpacity>
                <TouchableOpacity onPress={() => handleSave()} style={styles.actionButton}>
                    <Text style={styles.actionButtonText}>保存</Text>
                </TouchableOpacity>
            </View>

            <View style={styles.card}>
                <Text style={styles.header}>
                    {evaluationItem.courseName}——{evaluationItem.teacherName}
                    {"  "}
                    <Text style={styles.statusBadge}>{evaluationItem.submitStatus}</Text>
                </Text>
                {teachers![0].categories.map((cat: any, catIdx: number) => (
                    <EvaCategory key={cat.name + cat.qzz} cat={cat} catIdx={catIdx} onSelect={onSelect} />
                ))}
            </View>

            <View style={styles.commentCard}>
                <Text style={styles.commentLabel}>评语</Text>
                <TouchableOpacity
                    style={styles.commentInput}
                    onPress={() => {
                        navigation.navigate("EvaluationComment", {
                            initialComment: comment,
                            onSave: (newComment: string) => {
                                dispatch({type: "SET_COMMENT", payload: newComment});
                                setTimeout(() => scrollViewRef.current?.scrollToEnd({animated: true}), 100);
                            },
                        });
                    }}>
                    <Text style={comment ? styles.commentText : styles.commentPlaceholder}>
                        {comment || "点击输入评语"}
                    </Text>
                </TouchableOpacity>
            </View>
        </ScrollView>
    );
}
