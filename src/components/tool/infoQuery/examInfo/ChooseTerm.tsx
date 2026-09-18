import {ScrollView, StyleSheet, Text, TouchableOpacity, View} from "react-native";
import {useEffect, useMemo, useState} from "react";
import {useTheme} from "@rneui/themed";
import {useJwAccount} from "@/core/auth/Jw/hooks/useJwAccount.ts";
import {userProfileRepo} from "@/core/repo/userProfileRepo.ts";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import {prevTerm} from "@/features/courseSchedule/utils/prevTerm.ts";

interface ChooseTermProps {
    // year 传空字符串表示"全历史"
    onTermSelect?: (year: number | "", term: string) => void;
    // 是否包含"全学年"选项，默认为 true
    includeWholeYear?: boolean;
    includeWholeLife?: boolean;
    /**
     * 假期时默认查看哪一侧的学期：
     * - "past"：看刚结束的学期（适合考试信息、成绩--放假后最关心上一学期结果）。
     * - "future"：看即将开始的学期（适合课表--放假后要为下学期做准备）。
     * 学期内时忽略此参数，始终默认当前学期。默认 "past"。
     */
    vacationDefault?: "past" | "future";
}

type FilterType = "all" | "no_future" | "current";

export function ChooseTerm({
    onTermSelect,
    includeWholeLife = true,
    includeWholeYear = true,
    vacationDefault = "past",
}: ChooseTermProps) {
    const {theme} = useTheme();
    const {year: currentTermYear, term: currentTermCode, isStarted} = useStartDay();
    // 入学年份
    const [enrollmentYear, setEnrollmentYear] = useState<number>();

    // 学习年限
    const [studyYear, setStudyYear] = useState<number>(4);
    const {username} = useJwAccount();

    // 状态：显示范围过滤器
    const [filterType, setFilterType] = useState<FilterType>("no_future");

    const currentYear = new Date().getFullYear();
    const currentMonth = new Date().getMonth() + 1; // 1-12

    // 计算实际当前的学年（例如2026年2月，实际上属于2025-2026学年）
    // 简单逻辑：9月之前算上一年的学年
    const realAcademicYear = currentMonth < 9 ? currentYear - 1 : currentYear;

    const [selected, setSelected] = useState<{year: number | ""; term: string}>({year: "", term: ""});
    // --- 1. 数据生成与过滤逻辑 ---
    const academicYears = useMemo(() => {
        if (!enrollmentYear) return [];
        const yearNames = ["大一", "大二", "大三", "大四", "大五"];
        const years = [];

        for (let i = 0; i < studyYear; i++) {
            const startYear = enrollmentYear + i;
            years.push({
                name: yearNames[i] || `第${i + 1}年`,
                year: startYear,
            });
        }

        // 根据过滤器筛选
        switch (filterType) {
            case "current":
                return years.filter(y => y.year === realAcademicYear);
            case "no_future":
                // 只要开始年份不大于当前真实学年
                return years.filter(y =>
                    !isStarted && currentTermCode === 1 && vacationDefault === "future"
                        ? y.year <= realAcademicYear + 1
                        : y.year <= realAcademicYear,
                );
            case "all":
            default:
                return years;
        }
    }, [enrollmentYear, filterType, realAcademicYear, studyYear]);

    useEffect(() => {
        init(username);
    }, [username]);

    const init = async (account: string) => {
        if (!account) return;

        const info = await userProfileRepo.get(account);
        if (!info) return; // profile 尚未同步（如 OTA 后旧表被清），等启动补拉，不崩

        setEnrollmentYear(+info.grade);
        setStudyYear(info.study_years);
    };

    // 当 enrollmentYear 准备好之后，再计算并触发回调
    useEffect(() => {
        if (!enrollmentYear) return;
        if (!currentTermYear || !currentTermCode) return;

        let initYear: number | "";
        let initTerm: string;

        if (isStarted) {
            // 学期内：默认当前学期
            initYear = currentTermYear;
            initTerm = String(currentTermCode);
        } else if (vacationDefault === "future") {
            // 假期：看即将开始的学期，即 useStartDay 的 current（此时指向下学期）
            initYear = currentTermYear;
            initTerm = String(currentTermCode);
        } else {
            // 假期 + past：看刚结束的学期，回退一个学期。
            // 回退到入学前则无意义（如大一开学前的暑假），兜底退回 current。
            const prev = prevTerm(currentTermYear, currentTermCode);
            if (prev.year < enrollmentYear) {
                initYear = currentTermYear;
                initTerm = String(currentTermCode);
            } else {
                initYear = prev.year;
                initTerm = String(prev.term);
            }
        }

        setSelected({year: initYear, term: initTerm});
        onTermSelect?.(initYear, initTerm);
    }, [enrollmentYear, currentTermYear, currentTermCode, isStarted, vacationDefault]);

    // --- 2. 交互处理 ---

    // 选择学年 (点击上方横向滚动条)
    const handleYearPress = (year: number) => {
        // 如果当前是"所有历史"状态，点击学年时，默认选中"秋季"作为学期，提升体验
        const nextTerm = selected.year === "" ? "1" : selected.term;

        setSelected({year, term: nextTerm});
        onTermSelect?.(year, nextTerm);
    };

    // 选择学期 (点击下方按钮)
    const handleTermPress = (term: string) => {
        // 如果当前是"所有历史"状态(year为空)，点击学期时，自动选中列表里的最近一个学年
        // 否则用户会很困惑"我选了学期为什么没反应"
        let nextYear = selected.year;
        if (nextYear === "") {
            const latest = academicYears[academicYears.length - 1];
            nextYear = latest ? latest.year : (enrollmentYear ?? 0);
        }

        setSelected({year: nextYear, term});
        onTermSelect?.(nextYear, term);
    };

    const handleHistoryPress = () => {
        const target = {year: "" as const, term: ""}; // year留空，term留空
        setSelected(target);
        onTermSelect?.(target.year, target.term);
    };

    const termOptions = [
        {label: "秋季学期", term: "1"},
        {label: "春季学期", term: "2"},
        ...(includeWholeYear ? [{label: "全学年", term: ""}] : []),
    ];

    const styles = StyleSheet.create({
        container: {
            padding: 16,
        },
        header: {
            flexDirection: "row",
            justifyContent: "space-between",
            alignItems: "center",
            marginBottom: 12,
        },
        title: {
            fontSize: 16,
            fontWeight: "bold",
            color: theme.colors.black,
        },
        filterContainer: {
            flexDirection: "row",
            backgroundColor: theme.colors.grey5,
            borderRadius: 8,
            padding: 2,
        },
        filterBtn: {
            paddingHorizontal: 10,
            paddingVertical: 4,
            borderRadius: 6,
        },
        filterBtnActive: {
            backgroundColor: theme.colors.white,
            shadowColor: "#000",
            shadowOffset: {width: 0, height: 1},
            shadowOpacity: 0.1,
            shadowRadius: 1,
            elevation: 1,
        },
        filterText: {
            fontSize: 12,
            color: theme.colors.grey3,
        },
        filterTextActive: {
            color: theme.colors.primary,
            fontWeight: "600",
        },
        // 历史按钮
        historyBtn: {
            width: "100%",
            paddingVertical: 12,
            backgroundColor: selected.year === "" ? theme.colors.primary : theme.colors.grey5,
            borderRadius: 8,
            alignItems: "center",
            marginBottom: 16,
        },
        historyBtnText: {
            fontSize: 15,
            fontWeight: "bold",
            color: selected.year === "" ? theme.colors.white : theme.colors.grey2,
        },
        // 学年滚动区
        yearScroll: {
            marginBottom: 12,
        },
        yearItem: {
            paddingHorizontal: 16,
            paddingVertical: 8,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: theme.colors.grey4,
            marginRight: 8,
            backgroundColor: theme.colors.white,
        },
        yearItemSelected: {
            backgroundColor: `${theme.colors.primary}15`, // 浅色背景
            borderColor: theme.colors.primary,
        },
        yearText: {
            fontSize: 15,
            color: theme.colors.grey2,
        },
        yearTextSelected: {
            color: theme.colors.primary,
            fontWeight: "bold",
        },
        // 学期按钮行
        termRow: {
            flexDirection: "row",
            gap: 8, // 按钮间距
        },
        termBtn: {
            flex: 1, // 核心：自动平分宽度，适配2个或3个按钮
            paddingVertical: 12,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: theme.colors.grey4,
            alignItems: "center",
            justifyContent: "center",
            backgroundColor: theme.colors.white,
        },
        termBtnSelected: {
            backgroundColor: theme.colors.primary,
            borderColor: theme.colors.primary,
        },
        termText: {
            fontSize: 14,
            color: theme.colors.grey2,
        },
        termTextSelected: {
            color: theme.colors.white,
            fontWeight: "bold",
        },
        sectionLabel: {
            fontSize: 12,
            color: theme.colors.grey3,
            marginBottom: 6,
            marginTop: 4,
        },
    });

    return (
        enrollmentYear && (
            <View style={styles.container}>
                {/* 顶部：标题 + 过滤器 */}
                <View style={styles.header}>
                    <Text style={styles.title}>学期范围</Text>
                    <View style={styles.filterContainer}>
                        {[
                            {key: "current", label: "当前"},
                            {key: "no_future", label: "至今"},
                            {key: "all", label: "全部"},
                        ].map(f => (
                            <TouchableOpacity
                                key={f.key}
                                style={[styles.filterBtn, filterType === f.key && styles.filterBtnActive]}
                                onPress={() => setFilterType(f.key as FilterType)}>
                                <Text style={[styles.filterText, filterType === f.key && styles.filterTextActive]}>
                                    {f.label}
                                </Text>
                            </TouchableOpacity>
                        ))}
                    </View>
                </View>

                {/* 功能按钮：所有历史数据 */}
                {includeWholeLife && (
                    <TouchableOpacity style={styles.historyBtn} onPress={handleHistoryPress} activeOpacity={0.8}>
                        <Text style={styles.historyBtnText}>入学以来所有数据</Text>
                    </TouchableOpacity>
                )}

                {/* 具体的学年/学期选择区域 */}
                {/* 当选中"所有历史"时，下方半透明显示，暗示当前生效的是上面的按钮 */}
                <View style={{opacity: selected.year === "" ? 0.5 : 1}}>
                    <Text style={styles.sectionLabel}>选择学年</Text>
                    <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.yearScroll}>
                        {academicYears.map(ay => {
                            const isSelected = selected.year === ay.year;
                            return (
                                <TouchableOpacity
                                    key={ay.year}
                                    style={[styles.yearItem, isSelected && styles.yearItemSelected]}
                                    onPress={() => handleYearPress(ay.year)}>
                                    <Text style={[styles.yearText, isSelected && styles.yearTextSelected]}>
                                        {ay.name} ({ay.year})
                                    </Text>
                                </TouchableOpacity>
                            );
                        })}
                    </ScrollView>

                    <Text style={styles.sectionLabel}>选择学期</Text>
                    <View style={styles.termRow}>
                        {termOptions.map(t => {
                            // 只有在没选"所有历史"且term匹配时才高亮
                            const isSelected = selected.year !== "" && selected.term === t.term;
                            return (
                                <TouchableOpacity
                                    key={t.term}
                                    // flex: 1 使得只有两个按钮时也会自动撑满一行
                                    style={[styles.termBtn, isSelected && styles.termBtnSelected]}
                                    onPress={() => handleTermPress(t.term)}>
                                    <Text style={[styles.termText, isSelected && styles.termTextSelected]}>
                                        {t.label}
                                    </Text>
                                </TouchableOpacity>
                            );
                        })}
                    </View>
                </View>
            </View>
        )
    );
}
