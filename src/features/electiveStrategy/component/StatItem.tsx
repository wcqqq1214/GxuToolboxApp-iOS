import {StyleSheet, Text, View} from "react-native";
import {useMemo} from "react";
import {useTheme} from "@rneui/themed";

export const StatItem = ({label, value, passed}: {label: string; value: string | number; passed: boolean | null}) => {
    const {theme} = useTheme();
    const styles = useMemo(() => style(theme), [theme]);
    return (
        <View style={styles.statItem}>
            <Text style={styles.statLabel}>{label}</Text>
            <Text
                style={[
                    styles.statValue,
                    passed === null ? styles.textPending : passed ? styles.textSuccess : styles.textDanger,
                ]}>
                {value}
            </Text>
        </View>
    );
};
const style = (theme: any) =>
    StyleSheet.create({
        statItem: {
            flexDirection: "row",
            justifyContent: "space-between",
            alignItems: "center",
            paddingVertical: 6,
        },
        statLabel: {
            flex: 1,
            fontSize: 15,
            color: theme.colors.black,
        },
        statValue: {
            fontSize: 15,
            fontWeight: "bold",
        },
        textSuccess: {
            color: "#5cb85c", // 绿色
        },
        textPending: {
            color: theme.colors.grey2,
        },
        textDanger: {
            color: "#d9534f", // 红色
        },
    });
