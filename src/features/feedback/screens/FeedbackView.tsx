import {useLayoutEffect, useRef, useState} from "react";
import {Button, Platform, ScrollView, Text, ToastAndroid, View} from "react-native";
import {FormProvider, useForm} from "react-hook-form";
import {useNavigation} from "@react-navigation/native";
import * as FormItem from "@/features/feedback/components/formItem";
import {userMgr} from "@/js/mgr/user.ts";
import pkg from "../../../../package.json";
import {feedbackApi} from "@/features/backend/api/feedback.ts";

const APP_VERSION = pkg.version.split(" ")[0];

export class FeedbackForm {
    type: string;
    feature: string;
    content: string;
    contactType: string;
    contact: string;
}

export function FeedbackView() {
    const scrollRef = useRef<ScrollView>(null);
    const form = useForm<FeedbackForm>({
        defaultValues: {
            type: "",
            feature: "",
            content: "",
            contactType: "",
            contact: "",
        },
    });
    const [submitting, setSubmitting] = useState(false);
    const navigation = useNavigation<any>();

    useLayoutEffect(() => {
        navigation.setOptions({
            headerRight: () => (
                <Text
                    onPress={() => navigation.navigate("feedbackList")}
                    style={{color: "#1677ff", fontSize: 15, marginRight: 4}}>
                    我的反馈
                </Text>
            ),
        });
    }, [navigation]);

    const onSubmit = async (data: FeedbackForm) => {
        if (submitting) return;
        const account = await userMgr.jw.getAccount();
        if (!account?.username) {
            ToastAndroid.show("请先前往设置登录教务账号", ToastAndroid.SHORT);
            return;
        }
        const body = {
            userId: account.username,
            type: data.type,
            feature: data.feature,
            content: data.content,
            contactType: data.contactType,
            contact: data.contact,
            deviceModel: (Platform.constants as {Model?: string}).Model ?? "unknown",
            appVersion: APP_VERSION,
        };
        try {
            setSubmitting(true);
            const id = await feedbackApi.submit(body);
            ToastAndroid.show("提交成功", ToastAndroid.SHORT);
        } catch (e: any) {
            // 打印详细错误，便于定位：网络错误 vs 服务器返回错误
            console.warn("提交反馈失败:", e?.message, "status=", e?.response?.status, "data=", e?.response?.data);
            const msg = e?.response?.data?.message || e?.message || "网络错误";
            ToastAndroid.show("提交失败：" + msg, ToastAndroid.LONG);
        } finally {
            setSubmitting(false);
        }
    };

    function scrollToContentInput() {
        setTimeout(() => {
            scrollRef.current?.scrollTo({y: 220, animated: true});
        }, 250);
    }

    return (
        <View style={{flex: 1}}>
            <ScrollView
                ref={scrollRef}
                style={{flex: 1}}
                contentContainerStyle={{padding: 16, paddingBottom: 48}}
                keyboardShouldPersistTaps="handled"
                showsVerticalScrollIndicator={false}>
                <View style={{borderRadius: 16, backgroundColor: "#fff", padding: 16}}>
                    <FormProvider {...form}>
                        <FormItem.Pick
                            name="type"
                            label="反馈类型"
                            placeholder="请选择"
                            units={[
                                {label: "报告 Bug", value: "bug"},
                                {label: "功能建议", value: "suggestion"},
                                {label: "体验问题", value: "experience"},
                                {label: "其他", value: "other"},
                            ]}
                            rules={{
                                required: "请选择反馈类型",
                            }}
                        />

                        <FormItem.Chooser
                            name="feature"
                            label="问题模块"
                            options={[
                                {label: "课表", value: "schedule"},
                                {label: "成绩", value: "score"},
                                {label: "考试", value: "exam"},
                                {label: "账号登录", value: "auth"},
                                {label: "其他", value: "other"},
                            ]}
                            rules={{
                                required: "请选择问题模块",
                            }}
                        />

                        <FormItem.MultilineInput
                            name="content"
                            label="反馈内容"
                            placeholder="请描述你遇到的问题、操作步骤和期望结果"
                            onFocus={scrollToContentInput}
                            rules={{
                                required: "请填写反馈内容",
                                minLength: {
                                    value: 10,
                                    message: "反馈内容至少 10 个字",
                                },
                            }}
                        />

                        <FormItem.Pick
                            name="contactType"
                            label="联系方式类型"
                            placeholder="请选择"
                            units={[
                                {label: "QQ", value: "qq"},
                                {label: "微信", value: "wechat"},
                                {label: "邮箱", value: "email"},
                            ]}
                            rules={{
                                required: "请选择联系方式类型",
                            }}
                        />

                        <FormItem.Input
                            name="contact"
                            label="联系方式"
                            placeholder="请填写，方便我们联系你"
                            rules={{
                                required: "请填写联系方式",
                            }}
                        />
                    </FormProvider>

                    <View style={{marginTop: 24}}>
                        <Button
                            title={submitting ? "提交中..." : "提交"}
                            disabled={submitting}
                            onPress={form.handleSubmit(onSubmit)}
                        />
                    </View>
                </View>
            </ScrollView>
        </View>
    );
}
