import {Button, Dialog, Input, useTheme} from "@rneui/themed";
import {useCallback, useEffect, useState} from "react";
import {UnText, Icon} from "@/components/un-ui";
import {StyleSheet, View} from "react-native";

type Props = {
    isVisible: boolean;
    isBusy: boolean;
    isLogin: boolean;
    onBackdropPress: () => void;
    handleLogin: (username: string, password: string) => void;
    logout: () => void;
    username: string;
    password: string;
};

export function LoginDialog(props: Props) {
    const [username, setUsername] = useState(props.username);
    const [password, setPassword] = useState(props.password);
    const [secureTextEntry, setSecureTextEntry] = useState(true);

    const toggleSecureEntry = useCallback(() => {
        setSecureTextEntry(prev => !prev);
    }, []);

    useEffect(() => {
        setUsername(props.username);
        setPassword(props.password);
    }, [props.username, props.password]);

    const {theme} = useTheme();
    const styles = StyleSheet.create({
        inputLabel: {
            color: theme.colors.primary,
            fontSize: 16,
            fontWeight: "600",
        },
        inputView: {
            marginTop: 10,
        },
    });

    return (
        <Dialog
            isVisible={props.isVisible}
            onBackdropPress={() => {
                props.onBackdropPress();
            }}>
            <Dialog.Title title="登录文件系统" />
            <UnText>注：登录成功后会自动保存账号</UnText>
            <View style={styles.inputView}>
                <Input
                    label="账号（学号）"
                    value={username}
                    onChangeText={t => setUsername(t)}
                    labelStyle={styles.inputLabel}
                />
                <Input
                    label="密码（默认身份证前四位+后四位）"
                    value={password}
                    onChangeText={t => setPassword(t)}
                    labelStyle={styles.inputLabel}
                    secureTextEntry={secureTextEntry}
                    rightIcon={
                        <Icon
                            name={secureTextEntry ? "eye-slash" : "eye"}
                            type="fontawesome"
                            size={20}
                            color={theme.colors.grey3}
                            onPress={toggleSecureEntry}
                        />
                    }
                />
            </View>
            <Button
                title="登录"
                color={theme.colors.primary}
                disabled={props.isBusy}
                loading={props.isBusy}
                onPress={() => props.handleLogin(username, password)}
                style={{marginBottom: 8}}
            />
            <Button
                title="退出登录"
                color={theme.colors.primary}
                disabled={!props.isLogin}
                loading={props.isBusy}
                onPress={() => props.logout()}
            />
        </Dialog>
    );
}
