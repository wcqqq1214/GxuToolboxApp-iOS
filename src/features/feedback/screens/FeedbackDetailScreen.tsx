import {ScrollView, Text, View} from "react-native";
import {useRoute} from "@react-navigation/native";
import {FeedbackItemVM} from "@/features/backend/api/feedbackSchema.ts";
import dayjs from "dayjs";

// 反馈类型 / 问题模块的中文标签（与提交表单的取值对应）
const TYPE_LABELS: Record<string, string> = {
    bug: "报告 Bug",
    suggestion: "功能建议",
    experience: "体验问题",
    other: "其他",
};

const FEATURE_LABELS: Record<string, string> = {
    schedule: "课表",
    class_schedule: "课表",
    score: "成绩",
    exam: "考试",
    auth: "账号登录",
    other: "其他",
};

export function FeedbackDetailScreen() {
    const route = useRoute<any>();
    const item: FeedbackItemVM = route.params.item;

    return (
        <ScrollView style={{flex: 1}} contentContainerStyle={{padding: 16}}>
            {/* 状态 + 类型 */}
            <View style={{flexDirection: "row", alignItems: "center", marginBottom: 12}}>
                <Text
                    style={{
                        color: "#fff",
                        fontSize: 12,
                        paddingHorizontal: 8,
                        paddingVertical: 2,
                        borderRadius: 4,
                        backgroundColor: item.status === "accept" ? "#52c41a" : "#ff7875",
                    }}>
                    {item.status === "accept" ? "已回复" : "待回复"}
                </Text>
                <Text style={{marginLeft: 8, color: "#666", fontSize: 13}}>
                    {(TYPE_LABELS[item.type] ?? item.type) + " · " + (FEATURE_LABELS[item.feature] ?? item.feature)}
                </Text>
            </View>

            {/* 用户反馈内容 */}
            <View style={{backgroundColor: "#fff", borderRadius: 12, padding: 16}}>
                <Text style={{fontSize: 13, color: "#999", marginBottom: 6}}>我的反馈</Text>
                <Text style={{fontSize: 15, color: "#333", lineHeight: 22}}>{item.content}</Text>
                <Text style={{fontSize: 12, color: "#bbb", marginTop: 10}}>
                    {dayjs(item.createdAt).format("YYYY-MM-DD HH:mm")}
                </Text>
            </View>

            {/* 管理员回复 */}
            <View style={{backgroundColor: "#f6ffed", borderRadius: 12, padding: 16, marginTop: 12}}>
                {item.adminNote ? (
                    <>
                        <Text style={{fontSize: 13, color: "#52c41a", marginBottom: 6}}>
                            开发者回复 · {dayjs(item.updatedAt).format("YYYY-MM-DD HH:mm")}
                        </Text>
                        <Text style={{fontSize: 15, color: "#333", lineHeight: 22}}>{item.adminNote}</Text>
                    </>
                ) : (
                    <Text style={{fontSize: 14, color: "#999"}}>开发者尚未回复，请耐心等待</Text>
                )}
            </View>
        </ScrollView>
    );
}
