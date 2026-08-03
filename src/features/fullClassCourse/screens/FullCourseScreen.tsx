import {ActivityIndicator, SectionList, StyleSheet, View} from "react-native";
import {useEffect, useMemo, useState} from "react";
import {Schools, SchoolTermValue} from "@/type/global.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {classScheduleApi} from "@/features/classCourseSchedule/api";
import {normalizeCourse} from "@/features/classCourseSchedule/utils/normalizeCourse.ts";
import type {ClassDetail, Schedule} from "gxu-tool-adapters/jw";
import {Button, Divider, Text, useTheme} from "@rneui/themed";
import {useStartDay} from "@/features/courseSchedule/hooks/detail/useStartDay.ts";
import moment from "moment";
import {useCourseData} from "@/hooks/useCourseData.ts";
import type {ScheduleTableItem} from "@/features/courseSchedule/type/schedule.ts";

type SchoolType = (typeof Schools)[number];
const DAY_CN = ["", "一", "二", "三", "四", "五", "六", "日"];

interface TimeProps {
    week: number;
    day: number;
    classIndex: number;
}

function ClassCard({
    item,
    time,
    year,
    term,
    onCount,
}: {
    item: ClassDetail;
    time: TimeProps;
    year: number;
    term: SchoolTermValue;
    onCount: () => void;
}) {
    const [course, setCourse] = useState<ScheduleTableItem | null>(null);

    useEffect(() => {
        let cancelled = false;
        (async () => {
            try {
                const schedule: Schedule | null = await classScheduleApi.fetchClassSchedule(
                    String(year),
                    String(term),
                    item.majorId,
                    item.grade,
                    item.classId,
                );
                if (cancelled || !schedule) return;
                const items = normalizeCourse(schedule);
                const found = items.find(
                    i =>
                        i.week === time.week &&
                        i.day === time.day &&
                        i.begin <= time.classIndex &&
                        i.end >= time.classIndex,
                );
                if (!cancelled) setCourse(found ?? null);
            } catch {
                // 单个班级查询失败不阻塞整体
            }
        })();
        return () => {
            cancelled = true;
        };
    }, [item, time, year, term]);

    useEffect(() => {
        if (course) onCount();
    }, [course]);

    return (
        course && (
            <View style={styles.card}>
                <Text style={styles.cardTitle}>{course.title}</Text>
                <Text style={styles.cardSub}>{course.location}</Text>
                <Text style={styles.cardSub} numberOfLines={1}>
                    {course.teacher}
                </Text>
                <View style={{flex: 1}} />
                <Text style={styles.cardClassName}>{item.className}</Text>
            </View>
        )
    );
}

function MajorSection({
    majorId,
    classes,
    time,
    year,
    term,
    onSchoolCount,
}: {
    majorId: string;
    classes: ClassDetail[];
    time: TimeProps;
    year: number;
    term: SchoolTermValue;
    onSchoolCount: () => void;
}) {
    const [count, setCount] = useState<number>(0);
    const onCount = () => {
        setCount(prev => prev + 1);
        onSchoolCount();
    };
    return (
        <View style={styles.majorBlock}>
            {count !== 0 && (
                <Text style={styles.majorName}>
                    {majorId}（{count}）
                </Text>
            )}
            <View style={styles.classGrid}>
                {classes.map(item => (
                    <ClassCard key={item.classId} item={item} time={time} year={year} term={term} onCount={onCount} />
                ))}
            </View>
        </View>
    );
}

function SchoolHeader({school}: {school: SchoolType}) {
    const {theme} = useTheme();
    return (
        <View
            style={[
                styles.sectionHeader,
                {backgroundColor: theme.colors.background, borderBottomColor: theme.colors.greyOutline},
            ]}>
            <Text style={[styles.schoolName, {color: theme.colors.black}]}>{school[1]}</Text>
        </View>
    );
}

function SchoolContent({
    school,
    year,
    term,
    time,
}: {
    school: SchoolType;
    year: number;
    term: SchoolTermValue;
    time: TimeProps;
}) {
    const [list, setList] = useState<ClassDetail[]>([]);
    const [loading, setLoading] = useState(false);
    const [totalCount, setTotalCount] = useState<number>(0);
    const onSchoolCount = () => setTotalCount(prev => prev + 1);

    const fetchList = async () => {
        setLoading(true);
        setTotalCount(0);
        try {
            const res = await classScheduleApi.fetchFullClasses(String(year), String(term), school[0], "", "");
            setList(res ?? []);
        } catch {
            setList([]);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchList();
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [school, year, term]);

    const byMajor = list.reduce<Record<string, ClassDetail[]>>((acc, item) => {
        (acc[item.majorId] ??= []).push(item);
        return acc;
    }, {});

    return (
        <View style={styles.schoolBlock}>
            <View style={styles.contentHeaderRow}>
                {list.length > 0 && (
                    <Text style={{fontSize: 13, color: "#666", marginRight: 6}}>
                        {totalCount}/{list.length}
                    </Text>
                )}
                <Button title="获取数据" size="sm" onPress={fetchList} />
            </View>
            {loading && <ActivityIndicator style={{marginVertical: 6}} />}
            {!loading &&
                Object.entries(byMajor).map(([majorId, classes]) => (
                    <MajorSection
                        key={majorId}
                        majorId={majorId}
                        classes={classes}
                        time={time}
                        year={year}
                        term={term}
                        onSchoolCount={onSchoolCount}
                    />
                ))}
            <Divider style={{marginTop: 8}} />
        </View>
    );
}

type Section = {school: SchoolType; data: [SchoolType]};

export const FullCourseScreen = () => {
    const {theme} = useTheme();
    const {store} = useUserConfig();
    const [year] = useState(+store(s => s.jw.year));
    const [term] = useState<SchoolTermValue>(store(s => s.jw.term));
    const [currentTime] = useState(moment().format());
    const startDay = useStartDay(year, term);

    const week = moment().diff(startDay, "week") + 1;
    const day = moment().isoWeekday();

    const {store: courseStore} = useCourseData();
    const timeSpanList = courseStore(s => s.timeSpanList);

    function getCurrentTimeSpan() {
        let res = -1;
        timeSpanList.forEach((timeSpan, index, list) => {
            const start = index > 0 ? list[index - 1].split("\n")[1] : "00:00";
            const end = timeSpan.split("\n")[1];
            const startTime = moment(start, "hh:mm");
            const endTime = moment(end, "hh:mm");
            if (moment(currentTime).isBetween(startTime, endTime, undefined, "[]")) {
                res = index;
                return;
            }
        });
        return res > -1 ? res : null;
    }

    const classIndex = (getCurrentTimeSpan() ?? -1) + 1;
    const time: TimeProps = {week, day, classIndex};

    const sections: Section[] = useMemo(
        () => Schools.filter(i => i[1].includes("学院")).map(s => ({school: s, data: [s]})),
        [],
    );

    return (
        <View style={{flex: 1, backgroundColor: theme.colors.background}}>
            <View style={styles.timeHeader}>
                <Text style={styles.timeWeek}>
                    第 <Text style={[styles.timeNum, {color: theme.colors.black}]}>{week}</Text> 周
                </Text>
                <Text style={styles.timeDot}>·</Text>
                <Text style={styles.timeWeekday}>
                    星期<Text style={[styles.timeNum, {color: theme.colors.black}]}>{DAY_CN[day]}</Text>
                </Text>
                <Text style={styles.timeDot}>·</Text>
                <Text style={styles.timeWeekday}>
                    第<Text style={[styles.timeNum, {color: theme.colors.black}]}>{classIndex}</Text>节课
                </Text>
            </View>
            <SectionList
                sections={sections}
                stickySectionHeadersEnabled
                renderSectionHeader={({section}) => <SchoolHeader school={section.school} />}
                renderItem={({item}) => <SchoolContent school={item} year={year} term={term} time={time} />}
                keyExtractor={item => item[0]}
                contentContainerStyle={{paddingVertical: 8}}
            />
        </View>
    );
};

const styles = StyleSheet.create({
    sectionHeader: {
        backgroundColor: "#fff",
        paddingHorizontal: 12,
        paddingVertical: 10,
        borderBottomWidth: StyleSheet.hairlineWidth,
        borderBottomColor: "#ddd",
    },
    schoolBlock: {paddingHorizontal: 12, paddingTop: 6},
    contentHeaderRow: {flexDirection: "row", justifyContent: "flex-end", alignItems: "center", marginBottom: 8},
    schoolName: {fontSize: 18, fontWeight: "700"},
    majorBlock: {marginBottom: 10},
    majorName: {fontSize: 16, color: "#444", fontWeight: "600", marginBottom: 8, paddingLeft: 2},
    classGrid: {flexDirection: "row", flexWrap: "wrap", gap: 8},
    card: {
        width: "31%",
        backgroundColor: "#e8eaf0",
        borderRadius: 8,
        padding: 10,
        minHeight: 80,
        justifyContent: "space-between",
    },
    cardTitle: {fontSize: 16, fontWeight: "700", color: "#111", lineHeight: 20},
    cardSub: {fontSize: 14, color: "#666", lineHeight: 18, marginTop: 2},
    cardClassName: {fontSize: 13, color: "#999", marginTop: 8},
    empty: {fontSize: 14, color: "#888", paddingVertical: 4},
    timeHeader: {
        flexDirection: "row",
        justifyContent: "center",
        alignItems: "baseline",
        paddingVertical: 12,
        gap: 8,
    },
    timeWeek: {fontSize: 16, color: "#555"},
    timeWeekday: {fontSize: 16, color: "#555"},
    timeDot: {fontSize: 16, color: "#bbb"},
    timeNum: {fontSize: 22, fontWeight: "700", color: "#111"},
});
