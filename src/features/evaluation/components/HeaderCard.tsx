import {StyleSheet, Text, View} from "react-native";
import {useTheme} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";
import {useMemo, useState} from "react";
import {Icon} from "@/components/un-ui";

export const HeaderCard = ({evaList, onTemplate, onSubmit, onClear}) => {
    const {theme} = useTheme();

    const [header, setHeader] = useState<"status" | "function">("status");

    const styles = StyleSheet.create({
        statsCard: {
            backgroundColor: theme.colors.background,
            borderRadius: 12,
            padding: 16,
            alignSelf: "stretch",
        },
        statItem: {
            alignItems: "center",
            paddingHorizontal: 10,
            flex: 1,
        },
        statDivider: {
            width: 1,
            backgroundColor: theme.colors.divider,
            height: "100%",
            flex: 0,
        },
        statNumber: {
            fontSize: 24,
            fontWeight: "bold",
            marginBottom: 4,
        },
        statLabel: {
            fontSize: 12,
            color: theme.colors.grey3,
        },
    });

    const statusCounts = useMemo(() => {
        const cnt = {done: 0, undone: 0, undo: 0};
        evaList.forEach(item => {
            switch (item.submitStatus) {
                case "已评完":
                    cnt.done++;
                    break;

                case "未评完":
                    cnt.undone++;
                    break;
                case "未评":
                    cnt.undo++;
                    break;
                default:
                    break;
            }
        });
        return cnt;
    }, [evaList]);
    return (
        <View style={styles.statsCard}>
            {header === "function" ? (
                <Flex direction="row" justify="flex-start" inline>
                    <View style={styles.statItem}>
                        <Icon
                            name={"archive-cog-outline"}
                            size={30}
                            color={theme.colors.primary}
                            style={{marginBottom: 6}}
                            onPress={onTemplate}
                        />
                        <Text style={styles.statLabel}>评价模板</Text>
                    </View>
                    <View style={styles.statItem}>
                        <Icon
                            name={"check-all"}
                            size={30}
                            color={theme.colors.primary}
                            style={{marginBottom: 6}}
                            onPress={onSubmit}
                        />
                        <Text style={styles.statLabel}>一键评价</Text>
                    </View>
                    <View style={styles.statItem}>
                        <Icon
                            name={"package-variant-closed-remove"}
                            size={30}
                            color={theme.colors.primary}
                            style={{marginBottom: 6}}
                            onPress={onClear}
                        />
                        <Text style={styles.statLabel}>清空评价</Text>
                    </View>
                    <View style={styles.statItem}>
                        <Icon
                            name="swap-horizontal"
                            size={34}
                            color={theme.colors.primary}
                            onPress={() => setHeader("status")}
                        />
                    </View>
                </Flex>
            ) : (
                <Flex direction="row" justify="flex-start" inline>
                    <View style={styles.statItem}>
                        <Text style={[styles.statNumber, {color: theme.colors.black}]}>{evaList.length}</Text>
                        <Text style={styles.statLabel}>总计</Text>
                    </View>
                    <View style={styles.statItem}>
                        <Text style={[styles.statNumber, {color: theme.colors.success}]}>{statusCounts.done}</Text>
                        <Text style={styles.statLabel}>已评完</Text>
                    </View>
                    <View style={styles.statItem}>
                        <Text style={[styles.statNumber, {color: theme.colors.warning}]}>{statusCounts.undone}</Text>
                        <Text style={styles.statLabel}>未评完</Text>
                    </View>
                    <View style={styles.statItem}>
                        <Text style={[styles.statNumber, {color: theme.colors.error}]}>{statusCounts.undo}</Text>
                        <Text style={styles.statLabel}>未评</Text>
                    </View>
                    <View style={styles.statItem}>
                        <Icon
                            name="swap-horizontal"
                            size={34}
                            color={theme.colors.primary}
                            onPress={() => {
                                setHeader("function");
                            }}
                        />
                    </View>
                </Flex>
            )}
        </View>
    );
};
