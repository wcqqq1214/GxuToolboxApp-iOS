import React, {useCallback, useEffect, useState} from "react";
import {Alert, ScrollView, StyleSheet, Text, TouchableOpacity, View} from "react-native";
import {Button, Input, useTheme} from "@rneui/themed";
import AsyncStorage from "@react-native-async-storage/async-storage";

type LevelType = "非常满意" | "满意" | "一般" | "不满意" | "非常不满意";
const LEVELS: LevelType[] = ["非常满意", "满意", "一般", "不满意", "非常不满意"];
const EVALUATION_ITEMS: string[] = [
    "依法执教。任课教师遵守宪法和法律法规，贯彻党和国家教育方针，依法履责，在教育教学活动中无违背党的路线方针政策的不当言行。",
    "廉洁从教。任课教师严于律己，作风严谨正派；清廉从教，以身作则，无索要或收受学生及家长的财物馈赠行为。",
    "教书育人。任课教师遵循教育规律，维护课堂秩序；恪守学术规范，注重学思结合，因材施教，严慈相济，促进学生全面发展。",
    "立德树人。任课教师具优良教风，以高尚师德、人格魅力和学识风范教育感染学生；遵守社会公德，言行雅正；关心关爱、公正对待学生，做学生的良师益友。",
    "任课教师准时上下课，无调课、停课、缺课等现象。",
    "任课教师讲课有激情，精神饱满，有感染力，能吸引我的注意力。",
    "任课教师作业批改认真，课后我有疑问时，能得到老师的及时反馈与耐心指导。",
    "任课教师对课程内容娴熟，不照本宣科，与时俱进，难易得当，我能轻松理解。",
    "作业和考试既覆盖了课程的主要知识点，也能给我一定的发挥空间。",
    "任课教师制定并开展了“课程思政”教学设计，注重把思政教育融入课堂教学各环节。",
    "任课教师公布教学计划，明确告知教学目标、学习任务、考核方法、成绩构成比例并严格执行。",
    "任课教师能调动我的情绪，课堂气氛活跃、注重互动能激发我的学习兴趣。",
    "任课教师及时了解班级同学的学习进程、存在问题和学习效果，并作出相应调整与改进。",
    "该课程各教学环节的设置合理，使我有效学习、掌握课程相关知识、技能。",
    "本课程选用的教材、任课教师推荐的课程资源对我的学习有帮助。",
    "任课教师对我的思想言行和成长产生了积极影响，引导我树立正确的历史观、民族观、国家观、文化观和人生观。",
];
const CATEGORY_STRUCTURE = [
    [4, 3, 3, 3, 3], // 老师0: 第0类有4题, 第1类有3题, ...
];

// 新增：定义新的模板数据类型
export interface EvaluationTemplate {
    // 嵌套结构，键为教师索引 -> 类别索引 -> 题目索引，值为选项索引
    selected: Record<number, Record<number, Record<number, number>>>;
    comment: string;
}

const INIT_ANS = Object.fromEntries(EVALUATION_ITEMS.map((_, i) => [i, "满意"]));

// --- Storage Logic ---
const STORAGE_KEY = "@EvaluationTemplate";
async function saveTemplate(answers: Record<number, LevelType>, comment: string): Promise<void> {
    try {
        const selected: EvaluationTemplate["selected"] = {};
        let itemCounter = 0;

        CATEGORY_STRUCTURE.forEach((teacherCategories, teacherIdx) => {
            selected[teacherIdx] = {};
            teacherCategories.forEach((itemCount, categoryIdx) => {
                selected[teacherIdx][categoryIdx] = {};
                for (let i = 0; i < itemCount; i++) {
                    const itemIdx = itemCounter;
                    const answerText = answers[itemIdx];
                    const optionIdx = LEVELS.indexOf(answerText);
                    if (optionIdx !== -1) {
                        selected[teacherIdx][categoryIdx][i] = optionIdx;
                    }
                    itemCounter++;
                }
            });
        });

        const data: EvaluationTemplate = {selected, comment};
        const jsonValue = JSON.stringify(data);
        await AsyncStorage.setItem(STORAGE_KEY, jsonValue);
    } catch (e) {
        // ... 错误处理 ...
    }
}

async function loadTemplate(): Promise<{answers: Record<number, LevelType>; comment: string} | null> {
    try {
        const jsonValue = await AsyncStorage.getItem(STORAGE_KEY);
        if (jsonValue === null) return null;

        const storedData: EvaluationTemplate = JSON.parse(jsonValue);
        const answers: Record<number, LevelType> = {};
        let itemCounter = 0;

        CATEGORY_STRUCTURE.forEach((teacherCategories, teacherIdx) => {
            teacherCategories.forEach((itemCount, categoryIdx) => {
                for (let i = 0; i < itemCount; i++) {
                    const optionIdx = storedData.selected?.[teacherIdx]?.[categoryIdx]?.[i];
                    if (optionIdx !== undefined && LEVELS[optionIdx]) {
                        answers[itemCounter] = LEVELS[optionIdx];
                    } else {
                        if (i === 1)
                            answers[itemCounter] = "满意"; // Fallback
                        else answers[itemCount] = "非常满意";
                    }
                    itemCounter++;
                }
            });
        });

        return {answers, comment: storedData.comment || ""};
    } catch (e) {
        // ... 错误处理 ...
        return null;
    }
}

// --- Component ---
export function EvaluationTemplate() {
    const [answers, setAnswers] = useState<Record<number, LevelType>>(INIT_ANS);
    const [comment, setComment] = useState("");
    const {theme} = useTheme();

    useEffect(() => {
        const loadData = async () => {
            const storedData = await loadTemplate(); // loadTemplate 现在返回扁平结构
            if (storedData) {
                setAnswers(storedData.answers);
                setComment(storedData.comment);
            }
        };
        loadData();
    }, []);

    const handleAnswerChange = useCallback((index: number, val: LevelType) => {
        setAnswers(prev => ({...prev, [index]: val}));
    }, []);

    const handleSave = async () => {
        await saveTemplate(answers, comment);
        Alert.alert("成功", "模板已保存");
    };

    return (
        <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>
            <View style={styles.cardList}>
                <View style={styles.card}>
                    <Text style={styles.cardTitle}>评语</Text>
                    <Input
                        value={comment}
                        onChangeText={setComment}
                        placeholder="500字以内"
                        multiline
                        numberOfLines={4}
                        maxLength={500}
                        inputContainerStyle={styles.inputContainer}
                        inputStyle={styles.inputText}
                    />
                </View>
                {EVALUATION_ITEMS.map((item, index) => (
                    <QuestionCard
                        key={index}
                        index={index}
                        text={item}
                        value={answers[index] ?? "满意"} // Add fallback for safety
                        onChange={handleAnswerChange}
                        themeColor={theme.colors.primary}
                    />
                ))}
                {/* Save Button */}
                <Button
                    title="保存模板"
                    onPress={handleSave}
                    containerStyle={styles.buttonContainer}
                    buttonStyle={{backgroundColor: theme.colors.primary}}
                />
            </View>
        </ScrollView>
    );
}

/* -------------------- 单题卡片 -------------------- */
const QuestionCard = React.memo(
    ({
        index,
        text,
        value,
        onChange,
        themeColor,
    }: {
        index: number;
        text: string;
        value: LevelType;
        onChange: (index: number, val: LevelType) => void;
        themeColor: string;
    }) => {
        return (
            <View style={styles.card}>
                <Text style={styles.cardTitle}>
                    {index + 1}. {text}
                </Text>
                <View style={styles.radioRow}>
                    {LEVELS.map(lv => {
                        const active = value === lv;
                        return (
                            <TouchableOpacity
                                key={lv}
                                activeOpacity={0.7}
                                style={[
                                    styles.radioWrap,
                                    active && {
                                        borderColor: themeColor,
                                        backgroundColor: `${themeColor}15`,
                                    },
                                ]}
                                onPress={() => onChange(index, lv)}>
                                <View style={[styles.radioDot, active && {backgroundColor: themeColor}]} />
                                <Text style={[styles.radioText, active && {color: themeColor, fontWeight: "600"}]}>
                                    {lv}
                                </Text>
                            </TouchableOpacity>
                        );
                    })}
                </View>
            </View>
        );
    },
);

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: "#f2f5fa",
    },
    cardList: {
        paddingHorizontal: 16,
        paddingTop: 24,
        paddingBottom: 40,
    },
    card: {
        backgroundColor: "#fff",
        padding: 20,
        marginBottom: 16,
        shadowColor: "#000",
        shadowOffset: {width: 0, height: 2},
        shadowOpacity: 0.05,
    },
    cardTitle: {
        fontSize: 15,
        lineHeight: 24,
        color: "#262626",
        marginBottom: 16,
        fontWeight: "500",
    },
    radioRow: {
        flexDirection: "row",
        justifyContent: "space-between",
        gap: 8,
    },
    radioWrap: {
        flex: 1,
        alignItems: "center",
        justifyContent: "center",
        paddingVertical: 12,
        borderRadius: 12,
        borderWidth: 1,
        borderColor: "#f0f0f0",
        backgroundColor: "#fafafa",
    },
    radioDot: {
        width: 10,
        height: 10,
        borderRadius: 5,
        backgroundColor: "#d9d9d9",
        marginBottom: 8,
    },
    radioText: {
        fontSize: 12,
        color: "#595959",
        textAlign: "center",
    },
    inputContainer: {
        borderBottomWidth: 0,
        paddingHorizontal: 0,
    },
    inputText: {
        textAlignVertical: "top",
        backgroundColor: "#fafafa",
        borderWidth: 1,
        borderColor: "#f0f0f0",
        borderRadius: 8,
        padding: 10,
        fontSize: 14,
        lineHeight: 20,
        minHeight: 80,
    },
    buttonContainer: {
        marginHorizontal: 16,
        marginTop: 10,
        marginBottom: 30,
    },
});
