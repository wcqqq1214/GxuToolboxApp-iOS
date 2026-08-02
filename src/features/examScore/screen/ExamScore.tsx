import {ActivityIndicator, ScrollView, StyleSheet, TouchableOpacity, View} from "react-native";
import {Button, Divider, Text, useTheme} from "@rneui/themed";
import React, {useCallback, useEffect, useMemo, useState} from "react";
import Flex from "@/components/un-ui/Flex.tsx";
import {Color} from "@/shared/color.ts";
import {ExamScoreTable} from "@/features/examScore/component/ExamScoreTable.tsx";
import {useNavigation} from "@react-navigation/native";
import {ChooseTerm} from "@/components/tool/infoQuery/examInfo/ChooseTerm.tsx";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {Icon, UnJsonEditor, UnPressable, UnText} from "@/components/un-ui";
import {useScore} from "@/features/examScore/hooks/useScore.ts";

export function ExamScore() {
    const {store: ucStore} = useUserConfig();
    const devMode = ucStore(s => s.devMode);
    const {theme} = useTheme();
    const navigation = useNavigation();
    const [year, setYear] = useState("");
    const [term, setTerm] = useState("");
    const [page, setPage] = useState(1);
    const {scores, isLoading, loadLocal, fetchRemote, lastSyncTime} = useScore();

    const [notScore, setNotScore] = useState<string[]>([""]);
    const style = useMemo(() => {
        return StyleSheet.create({
            container: {
                padding: "5%",
            },
            table: {
                width: "100%",
            },
            tableText: {
                color: theme.colors.black,
                margin: 5,
            },
            tableBorder: {
                borderWidth: 2,
                borderColor: Color.mix(theme.colors.primary, theme.colors.grey4, 0.4).rgbaString,
            },
            tableHeader: {
                backgroundColor: Color.mix(
                    Color(theme.colors.primary),
                    Color(theme.colors.background),
                    theme.mode === "dark" ? 0.7 : 0.2,
                ).setAlpha(theme.mode === "dark" ? 0.3 : 0.6).rgbaString,
            },
            tableHeaderText: {},
            gpaCal: {
                backgroundColor: theme.colors.primary,
                paddingVertical: 10,
                paddingHorizontal: 12,
                borderRadius: 6,
            },
        });
    }, [theme]);

    const query = useCallback(async () => {
        if (!year || year === "") return;

        const localTerm = term === "3" ? 1 : 2;

        // 瞬间加载本地数据顶上（不阻塞）
        await loadLocal(+year, localTerm);

        // 紧接着发起远端请求静默更新
        // 注意这里不要 await 它，让它在后台慢慢跑，跑完了 Hook 会自动 setScores 刷新界面
        fetchRemote(+year, term, page).catch(console.error);
    }, [year, term, page, loadLocal, fetchRemote]);

    // 当学年、学期、页码改变时，自动触发
    useEffect(() => {
        query();
    }, [query]);

    return (
        <ScrollView>
            <ChooseTerm
                onTermSelect={(Year, Term) => {
                    setYear(Year);
                    setTerm(Term);
                }}
                includeWholeLife={false}
                includeWholeYear={false}
            />
            <View style={style.container}>
                <Flex direction="column" style={{alignSelf: "stretch", marginBottom: 12}} gap={4}>
                    {scores.length > 0 && (
                        <>
                            <Flex
                                justify="space-between"
                                align="center"
                                style={{alignSelf: "stretch", marginBottom: 12}}>
                                <Flex direction="column" align="flex-start" gap={4}>
                                    <Text h4 style={{margin: 0}}>
                                        查询结果
                                    </Text>
                                    <Flex align="center" gap={8}>
                                        {lastSyncTime && (
                                            <Text style={{fontSize: 12, color: "gray"}}>上次同步: {lastSyncTime}</Text>
                                        )}
                                        {isLoading && <ActivityIndicator size="small" color={theme.colors.primary} />}
                                    </Flex>
                                </Flex>
                                <TouchableOpacity
                                    onPress={() => navigation.navigate("gpaCalculator", {year, term})}
                                    style={style.gpaCal}>
                                    <Text style={{color: "white", fontSize: 16, fontWeight: "bold"}}>绩点计算器</Text>
                                </TouchableOpacity>
                            </Flex>

                            <Flex style={{width: "100%"}}>
                                <ExamScoreTable data={scores} year={year} term={term} />
                            </Flex>
                        </>
                    )}
                    {notScore.length > 0 && (
                        <View style={{width: "100%"}}>
                            <Text h4>未出分科目</Text>
                            <Divider style={{marginVertical: 10}} />
                            <View style={{flexDirection: "row", flexWrap: "wrap", gap: 10}}>
                                {notScore.map((courseName, index) => (
                                    <Button key={index} type={"outline"} radius={"lg"} color={theme.colors.primary}>
                                        {courseName}
                                    </Button>
                                ))}
                            </View>
                        </View>
                    )}
                    {devMode && (
                        <Flex gap={8} direction="column">
                            <ScheduleDataDebugCard label="查看考试成绩数据" data={scores} />
                            <ScheduleDataDebugCard label="查看未出分科目" data={notScore} />
                        </Flex>
                    )}
                </Flex>
            </View>
        </ScrollView>
    );
}

function ScheduleDataDebugCard({label, data}: {label: string; data: any}) {
    const {theme} = useTheme();
    const [modalOpen, setModalOpen] = useState(false);

    const styles = StyleSheet.create({
        card: {
            padding: 6,
            borderRadius: 4,
            backgroundColor: Color(theme.colors.error).setAlpha(theme.mode === "light" ? 0.5 : 0.3).rgbaString,
        },
    });
    return (
        <Flex>
            <UnPressable onPress={() => setModalOpen(true)}>
                <Flex style={styles.card} justify="flex-start" gap={4}>
                    <Icon name="console" size={16} inline />
                    <UnText weight="bold" size={16}>
                        {label}
                    </UnText>
                </Flex>
            </UnPressable>
            <UnJsonEditor.Modal readOnly visible={modalOpen} onClose={() => setModalOpen(false)} value={data} />
        </Flex>
    );
}
