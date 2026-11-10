import {Dialog, Image, Input, Text, useTheme} from "@rneui/themed";
import {NavigationProp, ParamListBase, useNavigation} from "@react-navigation/native";
import {useCallback, useEffect, useState} from "react";
import {ActivityIndicator, StyleSheet, ToastAndroid, View} from "react-native";
import {UnPressable} from "@/components/un-ui";
import {useAttendanceAuth} from "@/core/auth/attendance/hooks/useAttendanceAuth.ts";
import {useAttendanceAccount} from "@/core/auth/attendance/hooks/useAttendanceAccount.ts";

export interface AttendanceQuickLoginProps {
    visible?: boolean;
    onClose?: () => void;
    onSubmit?: (code: string) => void;
    onSucceed?: () => void;
    onFail?: (error: unknown) => void;
}

function getErrorMessage(error: unknown, fallback: string) {
    const apiError = error as {
        message?: string;
        response?: {data?: {message?: string}};
    };
    return apiError?.response?.data?.message ?? apiError?.message ?? fallback;
}

/**
 * 使用已保存账号完成考勤系统验证码登录。
 * 验证码图片、OCR 文本与 challenge token 必须由同一个认证 hook 管理。
 */
export function QuickLogin({visible = false, onClose, onSubmit, onSucceed, onFail}: AttendanceQuickLoginProps) {
    const {theme} = useTheme();
    const navigation = useNavigation<NavigationProp<ParamListBase>>();
    const {username, password, hydrating} = useAttendanceAccount();
    const {loading, login, refreshCaptcha, captchaLoading, captchaUri, captchaCode, setCaptchaCode} =
        useAttendanceAuth();
    const [errorMessage, setErrorMessage] = useState<string | null>(null);

    const hasAccount = Boolean(username.trim() && password.trim());
    const busy = hydrating || loading || captchaLoading;
    const normalizedCode = captchaCode.trim();

    const handleRefreshCaptcha = useCallback(async () => {
        setErrorMessage(null);
        try {
            await refreshCaptcha();
        } catch (error) {
            setErrorMessage(getErrorMessage(error, "验证码加载失败，请点击图片重试"));
        }
    }, [refreshCaptcha]);

    useEffect(() => {
        if (!visible || hydrating || !hasAccount) return;
        handleRefreshCaptcha().catch(() => undefined);
    }, [visible, hydrating, hasAccount, handleRefreshCaptcha]);

    async function handleLogin() {
        if (!hasAccount || normalizedCode.length !== 4) return;

        setErrorMessage(null);
        onSubmit?.(normalizedCode);

        try {
            const result = await login(username.trim(), password.trim(), normalizedCode);
            if (!result) return;

            ToastAndroid.show("登录成功", ToastAndroid.SHORT);
            onSucceed?.();
            onClose?.();
        } catch (error) {
            const message = getErrorMessage(error, "登录失败，请检查账号密码或验证码");
            setErrorMessage(message);
            ToastAndroid.show(message, ToastAndroid.SHORT);
            onFail?.(error);

            try {
                await refreshCaptcha();
            } catch {
                setErrorMessage(`${message}；新验证码加载失败，请点击图片重试`);
            }
        }
    }

    function handleConfigureAccount() {
        onClose?.();
        navigation.navigate("setting", {screen: "attendanceSystemAccount"});
    }

    return (
        <Dialog isVisible={visible} onBackdropPress={onClose}>
            <Dialog.Title title="快速登录考勤系统" titleStyle={{color: theme.colors.black}} />
            {hydrating ? (
                <View style={styles.loadingContainer}>
                    <ActivityIndicator />
                    <Text style={{color: theme.colors.grey2}}>正在读取账号…</Text>
                </View>
            ) : hasAccount ? (
                <>
                    <View style={styles.container}>
                        <Text style={{color: theme.colors.grey2}}>使用已保存账号登录，点击验证码可刷新</Text>
                        <UnPressable
                            accessibilityRole="button"
                            accessibilityLabel="刷新验证码"
                            disabled={busy}
                            onPress={handleRefreshCaptcha}>
                            <View style={[styles.imageContainer, {backgroundColor: theme.colors.grey5}]}>
                                {captchaUri ? (
                                    <Image style={styles.image} source={{uri: captchaUri}} />
                                ) : (
                                    <ActivityIndicator />
                                )}
                            </View>
                        </UnPressable>
                        <Input
                            value={captchaCode}
                            onChangeText={setCaptchaCode}
                            placeholder="请输入验证码"
                            maxLength={4}
                            autoCapitalize="none"
                            autoCorrect={false}
                            disabled={busy}
                            containerStyle={styles.inputContainer}
                        />
                        {errorMessage ? (
                            <Text style={[styles.errorText, {color: theme.colors.error}]}>{errorMessage}</Text>
                        ) : null}
                    </View>
                    <Dialog.Actions>
                        <Dialog.Button
                            title="登录"
                            loading={loading}
                            disabled={busy || normalizedCode.length !== 4 || !captchaUri}
                            onPress={handleLogin}
                        />
                    </Dialog.Actions>
                </>
            ) : (
                <>
                    <Text style={{color: theme.colors.grey2}}>暂未留存考勤系统账号，请先前往设置页配置。</Text>
                    {errorMessage ? (
                        <Text style={[styles.errorText, {color: theme.colors.error}]}>{errorMessage}</Text>
                    ) : null}
                    <Dialog.Actions>
                        <Dialog.Button title="前往设置" onPress={handleConfigureAccount} />
                    </Dialog.Actions>
                </>
            )}
        </Dialog>
    );
}

const styles = StyleSheet.create({
    container: {
        alignItems: "center",
        gap: 10,
    },
    loadingContainer: {
        minHeight: 90,
        alignItems: "center",
        justifyContent: "center",
        gap: 10,
    },
    imageContainer: {
        width: 190,
        height: 50,
        borderRadius: 6,
        alignItems: "center",
        justifyContent: "center",
        overflow: "hidden",
    },
    image: {
        width: 190,
        height: 50,
    },
    inputContainer: {
        paddingHorizontal: 0,
    },
    errorText: {
        alignSelf: "stretch",
        fontSize: 13,
        lineHeight: 18,
    },
});
