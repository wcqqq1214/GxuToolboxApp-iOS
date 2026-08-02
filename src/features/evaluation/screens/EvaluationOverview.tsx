import {useCallback, useMemo} from "react";
import {ScrollView, StyleSheet, View} from "react-native";
import {Row, Table} from "react-native-reanimated-table";
import {useFocusEffect, useNavigation} from "@react-navigation/native";
import {Color} from "@/shared/color.ts";
import {Button, Dialog, Text, useTheme} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";
import {EvaluationRow} from "@/features/evaluation/components/EvaluationRow.tsx";
import {EvaTeacherList} from "@/features/evaluation/types/schema/TeacherList.ts";
import {HeaderCard} from "@/features/evaluation/components/HeaderCard.tsx";
import {useEvaluationList} from "@/features/evaluation/hook/useEvaluationList.ts";
import {useEvaluationActions} from "@/features/evaluation/hook/useEvaluationActions.ts";

const ProgressBar = ({progress, color}: {progress: number; color: string}) => {
    const progressPercent = Math.round(progress * 100);
    return (
        <View style={{height: 4, backgroundColor: "#e0e0e0", borderRadius: 2}}>
            <View style={{height: "100%", width: `${progressPercent}%`, backgroundColor: color, borderRadius: 2}} />
        </View>
    );
};

export function EvaluationOverview() {
    const {list: evaList, init, statusCounts} = useEvaluationList();
    const {handleOneKey, handleClear, submit, isModalVisible, progress, progressText, cancel} = useEvaluationActions(
        evaList,
        init,
        () => navigation.navigate("EvaluationTemplate"),
    );

    const {theme} = useTheme();
    const navigation = useNavigation();

    const colWidths = [12, 6, 5];

    const handleRowPress = (item: EvaTeacherList) => {
        navigation.navigate("EvaluationDetail", {evaluationItem: item});
    };

    const softPrimaryBg = Color(theme.colors.primary).setAlpha(theme.mode === "dark" ? 0.18 : 0.1).rgbaString;
    const softPrimaryBorder = Color(theme.colors.primary).setAlpha(theme.mode === "dark" ? 0.45 : 0.28).rgbaString;
    const softPrimaryText = Color.mix(
        Color(theme.colors.primary),
        Color(theme.colors.black),
        theme.mode === "dark" ? 0.15 : 0.05,
    ).hexString();

    const styles = useMemo(
        () =>
            StyleSheet.create({
                container: {
                    paddingHorizontal: 10,
                    paddingVertical: 15,
                },
                header: {
                    height: 44,
                    backgroundColor: theme.colors.background,
                    borderTopLeftRadius: 8,
                    borderTopRightRadius: 8,
                    overflow: "hidden",
                },
                headerText: {
                    textAlign: "center",
                    fontWeight: "600",
                    color: theme.colors.primary,
                    fontSize: 16,
                },
                tableCard: {
                    backgroundColor: theme.colors.background,
                    borderRadius: 12,
                    padding: 12,
                    width: "100%",
                    overflow: "hidden",
                },
                row: {
                    height: 45,
                    borderBottomWidth: StyleSheet.hairlineWidth,
                    borderBottomColor: theme.colors.divider,
                    alignItems: "center",
                },
                rowText: {
                    textAlign: "center",
                    fontSize: 14,
                },
                buttonCard: {
                    backgroundColor: theme.colors.background,
                    borderRadius: 12,
                    padding: 12,
                    width: "100%",
                },
                opButton: {
                    backgroundColor: softPrimaryBg,
                    borderColor: softPrimaryBorder,
                    borderWidth: 1,
                    borderRadius: 8,
                    paddingHorizontal: 14,
                    paddingVertical: 8,
                    justifyContent: "center",
                },
                buttoText: {
                    color: softPrimaryText,
                    fontSize: 16,
                    fontWeight: "600",
                },
                submitButtonContainer: {
                    marginTop: 16,
                    marginBottom: 8,
                    width: "100%",
                },
                submitButton: {
                    backgroundColor: theme.colors.primary,
                    borderRadius: 12,
                    paddingVertical: 14,
                },
                submitButtonText: {
                    color: theme.colors.white,
                    fontSize: 16,
                    fontWeight: "700",
                },
                emptycontainer: {
                    alignItems: "center",
                    justifyContent: "center",
                    paddingVertical: 60,
                    paddingHorizontal: 24,
                },
                emptyTitle: {
                    textAlign: "center",
                    marginTop: 12,
                    fontSize: 18,
                    fontWeight: "bold",
                },
                emptyDoc: {
                    marginTop: 8,
                    fontSize: 14,
                    color: theme.colors.grey3,
                    textAlign: "center",
                    lineHeight: 22,
                },
            }),
        [theme],
    );

    const colorMap: Record<string, string> = {
        已评完: theme.colors.success,
        未评完: theme.colors.warning,
        未评: theme.colors.error,
    };

    useFocusEffect(
        useCallback(() => {
            init();
        }, []),
    );

    return (
        <ScrollView contentContainerStyle={styles.container}>
            {/* --- 进度弹窗 --- */}
            <Dialog isVisible={isModalVisible} overlayStyle={{borderRadius: 8}}>
                <Dialog.Title title="正在一键评教..." />
                <View style={{paddingHorizontal: 10, paddingVertical: 20}}>
                    <Text style={{fontSize: 16, marginBottom: 10}}>{progressText}</Text>
                    <ProgressBar progress={progress} color={theme.colors.primary} />
                </View>
                <Dialog.Actions>
                    <Button title="取消" type="clear" onPress={cancel} />
                </Dialog.Actions>
            </Dialog>

            <Flex direction="column" gap={10}>
                <HeaderCard
                    evaList={evaList}
                    onTemplate={() => {
                        navigation.navigate("EvaluationTemplate");
                    }}
                    onSubmit={handleOneKey}
                    onClear={handleClear}
                />
                <View style={styles.tableCard}>
                    <Table style={{width: "100%"}}>
                        <Row
                            data={["课程", "教师", "状态"]}
                            style={styles.header}
                            flexArr={colWidths}
                            textStyle={styles.headerText}
                        />
                        {evaList.map(item => (
                            <EvaluationRow
                                key={item.teachingClassId + item.securityToken}
                                item={item}
                                onPress={handleRowPress}
                                colorMap={colorMap}
                            />
                        ))}
                    </Table>
                </View>
                {evaList.length === 0 && (
                    <View style={styles.emptycontainer}>
                        <Text style={styles.emptyTitle}>暂无待评价课程</Text>
                        <Text style={styles.emptyDoc}>
                            当前可能未到期末学生评价开放时间，或所有课程暂未发布评价任务。
                        </Text>
                    </View>
                )}
            </Flex>
            {evaList.length > 0 && statusCounts.done === evaList.length && (
                <View style={styles.submitButtonContainer}>
                    <Button buttonStyle={styles.submitButton} onPress={submit}>
                        <Text style={styles.submitButtonText}>提交评价</Text>
                    </Button>
                </View>
            )}
        </ScrollView>
    );
}
