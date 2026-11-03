import {ActivityIndicator, ScrollView, StyleSheet, TextInput, View} from "react-native";
import {SafeAreaView} from "react-native-safe-area-context";
import {Button, Input, Text, useTheme} from "@rneui/themed";
import {useMemo, useRef, useState} from "react";
import {Icon} from "@/components/un-ui/Icon.tsx";
import {Flex, UnPressable, UnText} from "@/components/un-ui";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";
import {useJwAuth} from "@/core/auth/Jw/hooks/useJwAuth.ts";
import {AuthState, AuthStateMap} from "@/core/auth/auth.type.ts";
import {syncInfo} from "@/core/repo/userProfileServer.ts";
import {loginJwEvent} from "@/features/feedback/api/event";

function statusMeta(state: AuthState) {
    switch (state.status) {
        case AuthStateMap.NoAccount:
            return {label: "未配置账号", color: "#9CA3AF", bg: "#111827"};
        case AuthStateMap.HasAccountNotAuthenticated:
            return {label: "已保存账号（未登录/已失效）", color: "#F59E0B", bg: "#111827"};
        case AuthStateMap.Authenticated:
            return {label: "已登录", color: "#10B981", bg: "#111827"};
        default:
            return {label: "未知状态", color: "#EF4444", bg: "#111827"};
    }
}

export function JWAccountScreen() {
    const {username, setUsername, password, setPassword, hydrating, saveAccount} = useJwAccount();
    const {authState, loading, result, clearResult, login} = useJwAuth();
    const {theme} = useTheme();

    const [showPwd, setShowPwd] = useState<boolean>(false);

    const meta = useMemo(() => statusMeta(authState), [authState]);

    const busy = hydrating || loading;

    const pwdInputRef = useRef<TextInput>(null);
    const canSubmit = !busy && /^\d{10}$/.test(username) && password.length > 0;

    async function handleLogin() {
        clearResult();
        await saveAccount(username, password);
        const r = await login(username, password);

        // 登录成功后，记录登录事件，并把基础的用户信息写入数据库
        if (r.ok) {
            await loginJwEvent();
            syncInfo(username).catch(err => {
                console.warn(err);
            });
            return;
        }

        // 登录失败的情况都被login函数抛出了，不会到这里
    }

    return (
        <SafeAreaView style={{padding: "5%"}} edges={["bottom"]}>
            <ScrollView>
                <View style={{padding: 14}}>
                    <View style={styles.cardTopRow}>
                        <View style={styles.statusDotWrap}>
                            <View style={[styles.statusDot, {backgroundColor: meta.color}]} />
                        </View>
                        <Flex direction={"column"} flex={1} align={"flex-start"}>
                            <Text style={{color: "#9CA3AF", fontSize: 12}}>当前状态</Text>
                            <Text style={[styles.statusValue, {color: meta.color}]}>{meta.label}</Text>
                        </Flex>

                        {busy && (
                            <View style={{width: 22, alignItems: "flex-end"}}>
                                <ActivityIndicator size="small" />
                            </View>
                        )}
                    </View>

                    {result.kind !== "idle" && (
                        <View
                            style={[
                                styles.banner,
                                result.kind === "success" ? styles.bannerSuccess : styles.bannerError,
                            ]}>
                            <Text style={styles.bannerTitle}>{result.title}</Text>
                            {!!result.message && <Text style={styles.bannerMsg}>{result.message}</Text>}
                        </View>
                    )}

                    <Input
                        value={username}
                        onChangeText={v => setUsername(v.replace(/\s+/g, ""))}
                        label="学号"
                        keyboardType="number-pad"
                        returnKeyType="next"
                        maxLength={10}
                        autoCapitalize="none"
                        autoCorrect={false}
                        autoComplete="username"
                        textContentType="username"
                        onSubmitEditing={() => pwdInputRef.current?.focus()}
                        disabled={busy}
                        inputStyle={styles.inputText}
                        labelStyle={styles.inputLabel}
                        containerStyle={styles.inputContainer}
                        leftIcon={<Icon type="fontawesome" name="user" size={16} style={styles.leftIcon} />}
                    />

                    <Input
                        ref={pwdInputRef as any}
                        value={password}
                        onChangeText={v => setPassword(v)}
                        label="密码"
                        autoCapitalize="none"
                        returnKeyType="done"
                        autoCorrect={false}
                        autoComplete="password"
                        textContentType="password"
                        secureTextEntry={!showPwd}
                        disabled={busy}
                        onSubmitEditing={() => canSubmit && handleLogin()}
                        inputStyle={styles.inputText}
                        labelStyle={styles.inputLabel}
                        containerStyle={styles.inputContainer}
                        leftIcon={<Icon name="lock" size={16} style={styles.leftIcon} />}
                        rightIcon={
                            <UnPressable onPress={() => setShowPwd(s => !s)} disabled={busy}>
                                <Icon
                                    type="fontawesome"
                                    name={showPwd ? "eye-slash" : "eye"}
                                    size={18}
                                    style={styles.rightIcon}
                                />
                            </UnPressable>
                        }
                    />

                    <Button
                        onPress={handleLogin}
                        disabled={busy}
                        loading={busy}
                        radius={"lg"}
                        buttonStyle={{height: 40, gap: 10, marginTop: 8}}>
                        登录
                    </Button>
                    <Flex direction="column" gap={14} style={{marginTop: 28, paddingHorizontal: 4}}>
                        {[
                            {
                                icon: "form-textbox-password",
                                title: "本地加密存储",
                                desc: "密码仅保存在手机本地，不记录日志、不上传云服务器",
                            },
                            {
                                icon: "refresh-auto",
                                title: "24 小时永续登录",
                                desc: "打开应用即自动重登，告别频繁掉线与教务宵禁限制",
                            },
                            {
                                icon: "calendar-sync-outline",
                                title: "日程实时同步",
                                desc: "课表调整、考试安排实时更新，无需反复手动导入",
                            },
                        ].map(item => (
                            <Flex key={item.title} direction="row" align="flex-start" gap={12}>
                                <Flex
                                    inline
                                    align="center"
                                    justify="center"
                                    style={{
                                        width: 36,
                                        height: 36,
                                        borderRadius: 10,
                                        backgroundColor: "rgba(156,163,175,0.12)",
                                    }}>
                                    <Icon
                                        name={item.icon}
                                        size={20}
                                        color={
                                            authState.status === "authenticated"
                                                ? theme.colors.primary
                                                : theme.colors.grey2
                                        }
                                    />
                                </Flex>
                                <Flex direction="column" align="flex-start" gap={2} style={{flex: 1}}>
                                    <UnText
                                        size={15}
                                        bold
                                        color={
                                            authState.status === "authenticated"
                                                ? theme.colors.primary
                                                : theme.colors.grey2
                                        }>
                                        {item.title}
                                    </UnText>
                                    <UnText size={13} color="#9CA3AF" lineHeight={18}>
                                        {item.desc}
                                    </UnText>
                                </Flex>
                            </Flex>
                        ))}
                    </Flex>
                </View>
            </ScrollView>
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    page: {
        flex: 1,
        backgroundColor: "#0B1220",
    },
    container: {
        flex: 1,
        paddingHorizontal: 16,
        paddingTop: 18,
    },
    header: {
        marginBottom: 14,
    },
    title: {
        textAlign: "left",
        color: "#E5E7EB",
    },
    subtitle: {
        marginTop: 8,
        color: "#9CA3AF",
        fontSize: 13,
        lineHeight: 18,
    },

    cardTopRow: {
        flexDirection: "row",
        alignItems: "center",
        gap: 10,
        paddingBottom: 10,
        borderBottomWidth: 1,
        borderBottomColor: "rgba(255,255,255,0.06)",
        marginBottom: 10,
    },
    statusDotWrap: {
        width: 24,
        height: 24,
        borderRadius: 12,
        backgroundColor: "rgba(255,255,255,0.06)",
        alignItems: "center",
        justifyContent: "center",
    },
    statusDot: {
        width: 10,
        height: 10,
        borderRadius: 5,
    },
    statusValue: {
        marginTop: 2,
        fontSize: 14,
        fontWeight: "700",
    },

    banner: {
        borderRadius: 12,
        paddingVertical: 10,
        paddingHorizontal: 12,
        marginBottom: 8,
        borderWidth: 1,
    },
    bannerSuccess: {
        backgroundColor: "rgba(16,185,129,0.12)",
        borderColor: "rgba(16,185,129,0.35)",
    },
    bannerError: {
        backgroundColor: "rgba(239,68,68,0.12)",
        borderColor: "rgba(239,68,68,0.35)",
    },
    bannerTitle: {
        fontSize: 13,
        fontWeight: "800",
    },
    bannerMsg: {
        marginTop: 4,
        fontSize: 12,
        lineHeight: 16,
    },

    inputContainer: {
        paddingHorizontal: 0,
        marginTop: 6,
    },
    inputLabel: {
        fontSize: 16,
        fontWeight: "600",
    },
    inputText: {
        height: 60,
        fontSize: 18,
    },
    leftIcon: {
        paddingHorizontal: 6,
        color: "#9CA3AF",
    },
    rightIcon: {
        paddingHorizontal: 6,
        color: "#9CA3AF",
    },
});
