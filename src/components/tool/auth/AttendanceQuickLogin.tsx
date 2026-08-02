import {AttendanceSystemType as AST} from "@/type/api/auth/attendanceSystem.ts";
import {Dialog, Image, Input, Text, useTheme} from "@rneui/themed";
import {useEffect, useState} from "react";
import {ActivityIndicator, StyleSheet, ToastAndroid, View} from "react-native";
import {userMgr} from "@/js/mgr/user.ts";
import {attendanceAuthApi} from "@/core/auth/attendance/attendanceAuthApi.ts";
import {UnPressable} from "@/components/un-ui";
import {useAttendanceAuth} from "@/core/auth/attendance/hooks/useAttendanceAuth.ts";

export interface AttendanceQuickLoginProps {
    visible?: boolean;
    onClose?: () => void;
    onSubmit?: (code: string) => void;
    onSucceed?: (res: AST.ResRoot<AST.LoginData>) => void;
    onFail?: (res: any) => void;
}

export function AttendanceQuickLogin(props: AttendanceQuickLoginProps) {
    const {theme} = useTheme();
    const [captchaCode, setCaptchaCode] = useState("");
    const [captchaCodeUri, setCaptchaCodeUri] = useState("");
    const [accountData, setAccountData] = useState<{username: string; password: string}>();
    const {loading, login: loginAttendance} = useAttendanceAuth();

    async function refreshCaptchaCode() {
        const dataUri = await attendanceAuthApi.getCaptchaImage();
        setCaptchaCodeUri(dataUri);
        return dataUri;
    }

    async function login() {
        props.onSubmit?.(captchaCode);
        ToastAndroid.show("尝试登录考勤系统", ToastAndroid.SHORT);
        if (!accountData) return;
        const loginResult = await loginAttendance(accountData.username, accountData.password, captchaCode);
        if (!loginResult) return;
        const res = loginResult.loginRes;
        if (res.code === 600) {
            ToastAndroid.show("登录成功", ToastAndroid.SHORT);
            props.onSucceed?.(res);
            props.onClose?.();
        } else {
            ToastAndroid.show("登录失败，请检查账号密码是否正确或刷新验证码", ToastAndroid.SHORT);
            props.onFail?.(res);
        }
    }

    async function init() {
        await refreshCaptchaCode();
        const account = await userMgr.attendanceSystem.getAccount();
        if (account) setAccountData(account);
    }

    //从存储中读取数据
    useEffect(() => {
        init();
    }, []);

    const style = StyleSheet.create({
        image: {
            width: 190,
            height: 50,
        },
        container: {
            gap: 5,
            alignItems: "center",
        },
    });

    return (
        <Dialog isVisible={props.visible} onBackdropPress={props.onClose}>
            <Dialog.Title title="快速登录考勤系统" titleStyle={{color: theme.colors.black}} />
            {accountData ? (
                <>
                    <View style={style.container}>
                        <Text>填入验证码，使用内存中的账号登录考勤系统</Text>
                        <UnPressable onPress={refreshCaptchaCode}>
                            <Image
                                style={style.image}
                                source={{uri: captchaCodeUri}}
                                PlaceholderContent={<ActivityIndicator />}
                            />
                        </UnPressable>
                        <Input
                            onChange={e => setCaptchaCode(e.nativeEvent.text)}
                            value={captchaCode}
                            placeholder="填入上方验证码"
                        />
                    </View>
                    <Dialog.Actions>
                        <Dialog.Button title="登录" disabled={loading || captchaCode.length !== 4} onPress={login} />
                    </Dialog.Actions>
                </>
            ) : (
                <>
                    <Text>暂未设置考勤系统账号，请前往设置页设置考勤系统账号</Text>
                    <Dialog.Actions>
                        <Dialog.Button title="前往设置" onPress={login} />
                    </Dialog.Actions>
                </>
            )}
        </Dialog>
    );
}
