import {useCallback, useEffect, useState} from "react";
import {ActivityIndicator, FlatList, Pressable, RefreshControl, Text, View} from "react-native";
import {useNavigation} from "@react-navigation/native";
import {feedbackApi} from "@/features/backend/api/feedback.ts";
import {FeedbackItemVM} from "@/features/backend/api/feedbackSchema.ts";
import {userMgr} from "@/js/mgr/user.ts";
import dayjs from "dayjs";

export function FeedbackListScreen() {
    const navigation = useNavigation<any>();
    const [list, setList] = useState<FeedbackItemVM[]>([]); // 列表数据
    const [loading, setLoading] = useState(true); // 首次加载中
    const [refreshing, setRefreshing] = useState(false); // 下拉刷新中

    // 拉取"我的反馈列表"
    const loadList = useCallback(async () => {
        const account = await userMgr.jw.getAccount();
        if (!account?.username) {
            setList([]);
            return;
        }
        const data = await feedbackApi.getMyList(account.username);
        setList(data);
    }, []);

    // 页面首次出现时拉一次
    useEffect(() => {
        loadList().finally(() => setLoading(false));
    }, [loadList]);

    // 下拉刷新
    const onRefresh = useCallback(async () => {
        setRefreshing(true);
        await loadList();
        setRefreshing(false);
    }, [loadList]);

    // 首次加载中：显示转圈
    if (loading) {
        return (
            <View style={{flex: 1, justifyContent: "center", alignItems: "center"}}>
                <ActivityIndicator size="large" />
            </View>
        );
    }

    return (
        <FlatList
            data={list}
            keyExtractor={item => String(item.id)}
            contentContainerStyle={{padding: 16}}
            refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
            ListEmptyComponent={<Text style={{textAlign: "center", color: "#999", marginTop: 40}}>暂无提交的反馈</Text>}
            renderItem={({item}) => (
                <Pressable
                    onPress={() => navigation.navigate("feedbackDetail", {item})}
                    style={{backgroundColor: "#fff", borderRadius: 12, padding: 16, marginBottom: 12}}>
                    {/* 状态标签 */}
                    <Text
                        style={{
                            alignSelf: "flex-start",
                            color: "#fff",
                            fontSize: 12,
                            paddingHorizontal: 8,
                            paddingVertical: 2,
                            borderRadius: 4,
                            backgroundColor: item.status === "accept" ? "#52c41a" : "#ff7875",
                        }}>
                        {item.status === "accept" ? "已回复" : "待回复"}
                    </Text>
                    {/* 反馈内容预览（最多 2 行） */}
                    <Text numberOfLines={2} style={{fontSize: 18, color: "#333", marginTop: 8}}>
                        {item.content}
                    </Text>
                    {/* 时间 */}
                    <Text style={{fontSize: 14, color: "#999", marginTop: 8}}>
                        {dayjs(item.createdAt).format("YYYY-MM-DD HH:mm")}
                    </Text>
                </Pressable>
            )}
        />
    );
}
