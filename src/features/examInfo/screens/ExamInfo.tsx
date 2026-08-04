import {ActivityIndicator, ScrollView, StyleSheet, View} from "react-native";
import {Divider, Text, useTheme} from "@rneui/themed";
import React, {useEffect, useState} from "react";
import Flex from "@/components/un-ui/Flex.tsx";
import {store} from "@/core/store.ts";
import {Color} from "@/shared/color.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {getExamInfo} from "@/features/examInfo/api";
import {ExamInfoCard} from "@/features/examInfo/components/ExamInfoCard.tsx";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {parseExamTime} from "@/features/examInfo/utils/timeParser.ts";
import {ChooseTerm} from "@/components/tool/infoQuery/examInfo/ChooseTerm.tsx";
import {Icon, UnJsonEditor, UnPressable, UnText} from "@/components/un-ui";

export function ExamInfo() {
    const {theme} = useTheme();
    const {store: ucStore} = useUserConfig();
    const devMode = ucStore(s => s.devMode);
    const [examInfo, setExamInfo] = useState<ExamWithMeta[]>([]);
    const [year, setYear] = useState("");
    const [term, setTerm] = useState("");

    // 加载/错误态：首次加载用整页 loading，切换学期用局部 loading
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(false);
    const hasData = examInfo.length > 0;

    function init() {
        store
            .load({key: "examInfo"})
            .then(data => {
                // dayjs 对象经存储序列化后会丢失原型（变成 {}），
                // 这里用 time 字符串重新解析 date/status
                const restored: ExamWithMeta[] = (data ?? []).map((item: ExamWithMeta) => {
                    const {date, status} = parseExamTime(item.time);
                    return {...item, date, status};
                });
                setExamInfo(restored);
            })
            .catch(console.warn);
    }

    async function query() {
        if (!year || !term) return;

        setLoading(true);
        setError(false);
        try {
            const res = await getExamInfo(year, term);
            if (!res) {
                // 后端返回空或失败：清空旧数据，避免误导用户以为是上个学期的考试
                setExamInfo([]);
                return;
            }

            res.sort((a, b) => {
                // 1. 定义 status 优先级：upcoming(0) > tbd(1) > past(2)
                const statusOrder: Record<string, number> = {
                    upcoming: 0,
                    tbd: 1,
                    past: 2,
                };

                const orderA = statusOrder[a.status] ?? 3;
                const orderB = statusOrder[b.status] ?? 3;

                if (orderA !== orderB) {
                    return orderA - orderB;
                }

                // upcoming 升序，其他状态降序
                const sortDirection = orderA === 0 ? 1 : -1;
                const timeA = a.date?.valueOf() ?? 0;
                const timeB = b.date?.valueOf() ?? 0;
                return (timeA - timeB) * sortDirection;
            });

            setExamInfo(res);
            await store.save({key: "examInfo", data: res});
        } catch (e) {
            console.warn("查询考试信息失败:", e);
            setExamInfo([]);
            setError(true);
        } finally {
            setLoading(false);
        }
    }

    useEffect(() => {
        init();
    }, []);

    useEffect(() => {
        query();
    }, [year, term]);

    // 按状态分组渲染：upcoming/tbd 一组（未考），past 一组（已结束）
    const upcomingList = examInfo.filter(i => i.status !== "past");
    const pastList = examInfo.filter(i => i.status === "past");

    const renderSection = (title: string, list: ExamWithMeta[]) => {
        if (list.length === 0) return [];
        return (
            <View style={{width: "100%", gap: 15}}>
                <Flex align="center" gap={6}>
                    <Text style={{fontSize: 14, fontWeight: "bold", color: theme.colors.grey2}}>{title}</Text>
                    <Text style={{fontSize: 12, color: theme.colors.grey3}}>{list.length}门</Text>
                </Flex>
                {list.map(item => (
                    <ExamInfoCard key={item.id} item={item} />
                ))}
            </View>
        );
    };

    return (
        <ScrollView>
            <ChooseTerm
                onTermSelect={(Year, Term) => {
                    setYear(String(Year));
                    setTerm(Term);
                }}
                includeWholeLife={false}
                includeWholeYear={false}
            />
            <View style={{padding: "5%", paddingTop: 0}}>
                <Divider />
                <Flex direction="column" gap={15} align="flex-start">
                    <Flex align="flex-end" gap={5}>
                        <Text h4>查询结果</Text>
                        <Text>{`共有${examInfo.length}条结果`}</Text>
                    </Flex>

                    {/* 首次加载（无任何数据时）：整页 loading */}
                    {loading && !hasData && (
                        <View style={{width: "100%", alignItems: "center", paddingVertical: 60}}>
                            <ActivityIndicator size="large" color={theme.colors.primary} />
                            <Text style={{color: theme.colors.grey3, marginTop: 12}}>正在查询考试安排…</Text>
                        </View>
                    )}

                    {/* 切换学期时的局部 loading 条 */}
                    {loading && hasData && (
                        <View style={{width: "100%", alignItems: "center", paddingVertical: 8}}>
                            <ActivityIndicator size="small" color={theme.colors.primary} />
                        </View>
                    )}

                    {/* 错误态：可重试 */}
                    {error && !loading && (
                        <View
                            style={{
                                width: "100%",
                                alignItems: "center",
                                paddingVertical: 40,
                                gap: 12,
                            }}>
                            <Icon type="material" name="alert-circle-outline" size={40} color={theme.colors.error} />
                            <Text style={{color: theme.colors.grey2}}>查询失败，请稍后重试</Text>
                            <UnPressable
                                onPress={query}
                                style={{
                                    paddingHorizontal: 16,
                                    paddingVertical: 8,
                                    borderRadius: 6,
                                    backgroundColor: theme.colors.primary,
                                }}>
                                <UnText style={{color: "white"}}>重试</UnText>
                            </UnPressable>
                        </View>
                    )}

                    {/* 空数据态：非加载、非错误、无数据 */}
                    {!loading && !error && !hasData && (
                        <View style={{width: "100%", alignItems: "center", paddingVertical: 60}}>
                            <Icon type="material" name="calendar-blank-outline" size={48} color={theme.colors.grey3} />
                            <Text style={{color: theme.colors.grey3, marginTop: 12}}>本学期暂无考试安排</Text>
                        </View>
                    )}

                    {/* 正常数据：按状态分组 */}
                    {!loading && !error && hasData && (
                        <Flex direction="column" gap={20} align="flex-start" style={{width: "100%"}}>
                            {renderSection("即将开考", upcomingList)}
                            {renderSection("已结束", pastList)}
                        </Flex>
                    )}
                </Flex>
            </View>
            {devMode && (
                <Flex gap={8} direction="column" style={{padding: "5%"}}>
                    <ScheduleDataDebugCard label="查看考试考场数据" data={examInfo} />
                </Flex>
            )}
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
                    <Icon type="material" name="bug-outline" size={16} />
                    <UnText weight="bold" size={16}>
                        {label}
                    </UnText>
                </Flex>
            </UnPressable>
            <UnJsonEditor.Modal readOnly visible={modalOpen} onClose={() => setModalOpen(false)} value={data} />
        </Flex>
    );
}
