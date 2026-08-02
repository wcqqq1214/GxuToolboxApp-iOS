import {ActivityIndicator, ScrollView, StyleSheet, View} from "react-native";
import {SafeAreaView} from "react-native-safe-area-context";
import {Button, Input, Text} from "@rneui/themed";
import {useMemo, useState} from "react";
import {Icon} from "@/components/un-ui/Icon.tsx";
import {UnPressable} from "@/components/un-ui";
import {useWebView} from "@/hooks/app.ts";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";
import {useJwAuth} from "@/core/auth/Jw/hooks/useJwAuth.ts";
import {AuthState, AuthStateMap} from "@/core/auth/auth.type.ts";
import {syncInfo} from "@/core/repo/userProfileServer.ts";

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
    const {openInJw} = useWebView();
    const {username, setUsername, password, setPassword, hydrating, saveAccount} = useJwAccount();
    const {authState, loading, result, clearResult, login} = useJwAuth();

    const [showPwd, setShowPwd] = useState(false);

    const meta = useMemo(() => statusMeta(authState), [authState]);

    const busy = hydrating || loading;

    async function handleLogin() {
        clearResult();
        await saveAccount(username, password);
        const r = await login(username, password);

        // 登录成功后，记录登录事件，并把基础的用户信息写入数据库
        if (r.ok) {
            // await loginJwEvent();
            syncInfo(username).catch(err => {
                console.warn(err);
            });
            return;
        }

        // 登录失败的情况都被login函数抛出了，不会到这里
    }

    return (
        <SafeAreaView style={style.container} edges={["bottom"]}>
            <ScrollView>
                <View style={styles.card}>
                    <View style={styles.cardTopRow}>
                        <View style={styles.statusDotWrap}>
                            <View style={[styles.statusDot, {backgroundColor: meta.color}]} />
                        </View>
                        <View style={styles.statusTextWrap}>
                            <Text style={styles.statusLabel}>当前状态</Text>
                            <Text style={[styles.statusValue, {color: meta.color}]}>{meta.label}</Text>
                        </View>

                        {busy && (
                            <View style={styles.spinnerWrap}>
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
                        onChangeText={v => setUsername(v)}
                        label="学号"
                        autoCapitalize="none"
                        autoCorrect={false}
                        disabled={busy}
                        inputStyle={styles.inputText}
                        labelStyle={styles.inputLabel}
                        containerStyle={styles.inputContainer}
                        leftIcon={<Icon type="fontawesome" name="user" size={16} style={styles.leftIcon} />}
                    />

                    <Input
                        value={password}
                        onChangeText={v => setPassword(v)}
                        label="密码"
                        autoCapitalize="none"
                        autoCorrect={false}
                        secureTextEntry={!showPwd}
                        disabled={busy}
                        inputStyle={styles.inputText}
                        labelStyle={styles.inputLabel}
                        containerStyle={styles.inputContainer}
                        leftIcon={<Icon name="lock" size={16} style={styles.leftIcon} />}
                        rightIcon={
                            <UnPressable
                                onPress={function () {
                                    return setShowPwd(function (s) {
                                        return !s;
                                    });
                                }}
                                disabled={busy}>
                                <Icon
                                    type="fontawesome"
                                    name={showPwd ? "eye-slash" : "eye"}
                                    size={18}
                                    style={styles.rightIcon}
                                />
                            </UnPressable>
                        }
                    />

                    <View style={styles.actions}>
                        <Button onPress={handleLogin} disabled={busy} loading={busy}>
                            登录
                        </Button>

                        <Button type="outline" disabled={busy} onPress={() => openInJw("/xtgl/login_slogin.html")}>
                            打开教务登录页
                        </Button>
                    </View>
                    <Text style={style.note}>仅供工具从教务系统获取信息{"\n"}23:00 至次日 7:30 请连接校园网</Text>
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

    card: {
        borderRadius: 16,
        padding: 14,
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
    statusTextWrap: {
        flex: 1,
    },
    statusLabel: {
        color: "#9CA3AF",
        fontSize: 12,
    },
    statusValue: {
        marginTop: 2,
        fontSize: 14,
        fontWeight: "700",
    },
    spinnerWrap: {
        width: 22,
        alignItems: "flex-end",
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
        color: "#D1D5DB",
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

    actions: {
        marginTop: 8,
        gap: 10,
    },
    primaryBtn: {
        borderRadius: 12,
        height: 46,
        backgroundColor: "#2563EB",
    },
    primaryBtnTitle: {
        fontWeight: "800",
        fontSize: 14,
    },
    secondaryBtn: {
        borderRadius: 12,
        height: 44,
        borderColor: "rgba(255,255,255,0.16)",
    },
    secondaryBtnTitle: {
        color: "#E5E7EB",
        fontWeight: "700",
        fontSize: 13,
    },

    helperText: {
        marginTop: 12,
        color: "#9CA3AF",
        fontSize: 12,
        lineHeight: 16,
    },
});
const style = StyleSheet.create({
    container: {
        padding: "5%",
    },
    title: {
        textAlign: "center",
    },
    note: {
        marginVertical: 20,
        textAlign: "center",
        color: "gray",
        fontSize: 14,
    },
    showPwdIcon: {
        paddingHorizontal: 5,
        cursor: "pointer",
    },
    input: {
        height: 60,
    },
});
