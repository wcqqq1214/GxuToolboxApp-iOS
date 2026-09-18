import {ActivityIndicator, ScrollView, StyleSheet, View} from "react-native";
import {useEffect, useState} from "react";
import {getPersonalInfo} from "@/features/personalInfo/api";
import {ListItem, Text, useTheme} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";

const InfoRow = ({label, value, theme, styles}: {label: string; value?: string; theme: any; styles: any}) => (
    <ListItem bottomDivider containerStyle={{backgroundColor: "transparent"}}>
        <ListItem.Content>
            <Flex justify="space-between" style={{width: "100%"}}>
                <Text style={styles.label}>{label}</Text>
                <Text style={styles.value}>{`${value}`}</Text>
            </Flex>
        </ListItem.Content>
    </ListItem>
);

export const PersonalInfo = () => {
    const {theme} = useTheme();
    const [info, setInfo] = useState<any>();
    const [loading, setLoading] = useState(true);
    const init = async () => {
        const res = await getPersonalInfo();
        console.log(res);
        setInfo(res);
        setLoading(false);
        // const profile: UserProfile = {
        //     student_id: res
        // }
    };

    useEffect(() => {
        init();
    }, []);

    const styles = StyleSheet.create({
        container: {
            padding: 15,
        },
        header: {
            marginBottom: 20,
            paddingHorizontal: 10,
        },
        infoContainer: {
            backgroundColor: theme.mode === "dark" ? theme.colors.grey5 : theme.colors.white,
            borderRadius: 12,
            overflow: "hidden",
        },
        label: {
            color: theme.colors.grey3,
            fontSize: 14,
        },
        value: {
            color: theme.colors.black,
            fontSize: 16,
            fontWeight: "500",
        },
        noresContainer: {
            alignItems: "center",
            justifyContent: "center",
            minHeight: 260,
            gap: 15,
        },
    });

    if (loading) {
        return (
            <View style={styles.container}>
                <View style={[styles.infoContainer, styles.noresContainer]}>
                    <ActivityIndicator size="large" color={theme.colors.primary} />
                    <Text style={styles.label}>加载中....</Text>
                </View>
            </View>
        );
    }

    if (!info?.length) {
        return (
            <View style={styles.container}>
                <View style={[styles.noresContainer]}>
                    <Text style={styles.label}>暂无个人信息，请检查教务系统登录状态</Text>
                </View>
            </View>
        );
    }
    return (
        <ScrollView style={{backgroundColor: theme.colors.background}}>
            <View style={styles.container}>
                <View style={styles.infoContainer}>
                    {info.map((item: any) => (
                        <InfoRow label={item.label} value={item.value} theme={theme} styles={styles} />
                    ))}
                </View>
            </View>
        </ScrollView>
    );
};
