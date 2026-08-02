import {Text, useTheme} from "@rneui/themed";
import {ScrollView, StyleSheet, TextInput, TouchableOpacity, View} from "react-native";
import {RouteProp, useNavigation, useRoute} from "@react-navigation/native";
import {useCallback, useLayoutEffect, useState} from "react";

type CommentRouteParams = {
    initialComment?: string;
    onSave: (comment: string) => void;
};

type CommentScreenRouteProp = RouteProp<{params: CommentRouteParams}, "params">;

const PRESETS = [
    {
        label: "通用真诚",
        text: "老师专业功底深厚，治学态度严谨。教学中逻辑清晰，重点突出，善于运用启发式教学引导我们独立思考，将理论与实践紧密结合。课堂富有感染力，不仅传授了前沿知识，更点燃了我们对该领域的探索热情。是我们学术道路上当之无愧的引路人。",
    },
    {
        label: "侧重学术启发",
        text: "老师对课程内容娴熟，不照本宣科，与时俱进，难易得当，我能轻松理解。作业和考试既覆盖了主要知识点，也给了我发挥空间。课堂气氛活跃，注重互动，能激发我的学习兴趣。及时了解我们的学习进程并作出调整，教学效果显著。",
    },
    {
        label: "侧重人文关怀",
        text: "老师以高尚师德、人格魅力和学识风范教育感染我们，言行雅正，关心关爱每一位学生。准时上下课，无调课缺课现象。讲课有激情，精神饱满，有感染力。课后有疑问时能得到老师的及时反馈与耐心指导，是我们成长路上的良师益友。",
    },
];

export function EvaluationComment() {
    const {theme} = useTheme();
    const navigation = useNavigation();
    const route = useRoute<CommentScreenRouteProp>();

    const {initialComment, onSave} = route.params;
    const [text, setText] = useState(initialComment || "");

    const handleSave = useCallback(() => {
        onSave(text);
        navigation.goBack();
    }, [navigation, onSave, text]);

    useLayoutEffect(() => {
        navigation.setOptions({
            headerRight: () => (
                <TouchableOpacity
                    onPress={handleSave}
                    style={{
                        backgroundColor: theme.colors.primary,
                        borderRadius: 8,
                        paddingHorizontal: 14,
                        paddingVertical: 7,
                    }}>
                    <Text style={{color: theme.colors.white, fontSize: 14, fontWeight: "600"}}>保存</Text>
                </TouchableOpacity>
            ),
        });
    }, [navigation, handleSave, theme.colors.primary, theme.colors.white]);

    const styles = StyleSheet.create({
        container: {
            flex: 1,
        },
        content: {
            paddingHorizontal: 16,
            paddingTop: 20,
            paddingBottom: 40,
        },
        card: {
            backgroundColor: theme.colors.background,
            borderRadius: 12,
            padding: 16,
            marginBottom: 16,
        },
        textInput: {
            padding: 14,
            borderRadius: 10,
            borderWidth: 1,
            borderColor: theme.mode === "dark" ? "rgba(255,255,255,0.08)" : "#f0f0f0",
            backgroundColor: theme.mode === "dark" ? "rgba(255,255,255,0.03)" : "#fafafa",
            textAlignVertical: "top",
            fontSize: 14,
            lineHeight: 22,
            minHeight: 230,
            color: theme.colors.black,
        },
        counter: {
            textAlign: "right",
            marginTop: 8,
            fontSize: 12,
            color: text.length > 500 ? theme.colors.error : theme.colors.grey3,
        },
        sectionTitle: {
            fontSize: 15,
            fontWeight: "600",
            color: theme.colors.grey0,
            marginBottom: 12,
        },
        presetRow: {
            flexDirection: "row",
            flexWrap: "wrap",
            gap: 10,
        },
        presetChip: {
            paddingVertical: 8,
            paddingHorizontal: 16,
            borderRadius: 20,
            borderWidth: 1,
            borderColor: theme.mode === "dark" ? "rgba(255,255,255,0.1)" : "#e8e8e8",
            backgroundColor: theme.mode === "dark" ? "rgba(255,255,255,0.03)" : "#fafafa",
        },
        presetChipText: {
            fontSize: 13,
            color: theme.colors.grey1,
        },
    });

    return (
        <ScrollView style={styles.container} contentContainerStyle={styles.content}>
            <View style={styles.card}>
                <TextInput
                    style={styles.textInput}
                    value={text}
                    onChangeText={setText}
                    placeholder="请输入评语..."
                    placeholderTextColor={theme.colors.grey3}
                    multiline={true}
                    autoFocus={false}
                    maxLength={500}
                />
                <Text style={styles.counter}>{text.length}/500</Text>
            </View>

            <Text style={styles.sectionTitle}>快捷模板</Text>
            <View style={styles.presetRow}>
                {PRESETS.map(preset => (
                    <TouchableOpacity
                        key={preset.label}
                        style={styles.presetChip}
                        activeOpacity={0.7}
                        onPress={() => setText(preset.text)}>
                        <Text style={styles.presetChipText}>{preset.label}</Text>
                    </TouchableOpacity>
                ))}
            </View>
        </ScrollView>
    );
}
