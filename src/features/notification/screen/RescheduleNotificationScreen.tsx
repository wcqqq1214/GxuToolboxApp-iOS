import {ScrollView, StyleSheet, ToastAndroid, View} from "react-native";
import {useEffect, useMemo, useState} from "react";
import {jwxt} from "@/js/jw/jwxt.ts";
import {ButtonGroup, ListItem, Switch, Text, useTheme} from "@rneui/themed";
import {Icon} from "@/components/un-ui/Icon.tsx";
import {store} from "@/core/store.ts";

interface Notification {
    course: string;
    oldTeacher: string;
    oldWeek: string;
    oldWeekday: string;
    oldSection: string;
    oldPlace: string;
    newTeacher: string;
    newWeek: string;
    newWeekday: string;
    newSection: string;
    newPlace: string;
    time: string;
    text: string;
}

const ChangeDetail = ({label, oldValue, newValue}: {label: string; oldValue: string; newValue: string}) => {
    const {theme} = useTheme();
    return (newValue !== oldValue) ? (
        <View style={styles.detailRow}>
            <Text style={[styles.label, {color: theme.colors.grey1}]}>{label}:</Text>
            <View style={styles.changeContainer}>
                <Text style={styles.oldValue}> {oldValue} </Text>
                <Icon name="arrow-right" size={16} color={theme.colors.grey2} style={{marginHorizontal: 5}} />
                <Text style={styles.newValue}> {newValue} </Text>
            </View>
        </View>
    ) : null;
};

export function RescheduleNotificationScreen() {
    const {theme} = useTheme();
    const [notificationList, setNotificationList] = useState<Notification[]>([]);
    const [expandedIndex, setExpandedIndex] = useState<number | null>(null);
    const [loading, setLoading] = useState(false);
    const [selectedIndex, setSelectedIndex] = useState(0);
    const [startDay, setStartDay] = useState();
    const [showFull, setShowFull] = useState<boolean>(true);

    const reg = new RegExp(
        String.raw`:(?<oldTeacher>[\s\S]*?)老师` +
            String.raw`.?(?<oldWeek>第[\s\S]+周?)?星期(?<oldWeekday>[一二三四五六日])` +
            String.raw`第(?<oldSection>[\s\S]*?)节` +
            String.raw`在(?<oldPlace>[\s\S]*?)上的(?<course>[\s\S]*?)课程` +
            String.raw`.*?由(?<newTeacher>[\s\S]*?)老师` +
            String.raw`.*?在(?<newWeek>[\s\S]*周?)?星期(?<newWeekday>[一二三四五六日])` +
            String.raw`第(?<newSection>[\s\S]*?)节(?<newPlace>[\s\S]*?)上课`,
        "g",
    );

    const getNotifications = async (isRead: number) => {
        const userConfig = await store.load({key: "userConfig"}).catch(e => {
            console.warn(e);
        });
        setStartDay(userConfig.jw.startDay);
        setLoading(true);
        setNotificationList([]);
        setExpandedIndex(null);
        try {
            const res = await jwxt.getReschedulingNews(isRead);
            let res1: any = [];
            res.data.items.forEach((item: {xxnr: string; cjsj: string}) => {
                let m;
                while ((m = reg.exec(item.xxnr)) !== null) {
                    res1.push({...m.groups, time: item.cjsj, text: item.xxnr});
                }
            });
            setNotificationList(res1);
        } catch (e) {
            console.error("Failed to fetch news:", e);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        // 教务系统用 1 表示未读，2 表示已读
        getNotifications(selectedIndex + 1);
    }, [selectedIndex]);

    const filteredList = useMemo(() => {
        if (showFull || !startDay) {
            return notificationList;
        }
        return notificationList.filter(item => new Date(item.time) >= new Date(startDay));
    }, [notificationList, showFull, startDay]);

    return (
        <View style={{flex: 1}}>
            <ButtonGroup
                buttons={["未读消息", "已读消息"]}
                selectedIndex={selectedIndex}
                onPress={value => {
                    setSelectedIndex(value);
                }}
                containerStyle={{margin: 10, borderRadius: 8}}
            />
            <View style={styles.filterContainer}>
                <Text style={styles.filterText}>仅显示本学期</Text>
                <Switch value={!showFull} onValueChange={value => setShowFull(!value)} />
            </View>
            <ScrollView style={styles.container}>
                {loading ? (
                    <Text style={{textAlign: "center", padding: 20}}>加载中...</Text>
                ) : filteredList.length === 0 ? (
                    <Text style={{textAlign: "center", padding: 20}}>没有消息</Text>
                ) : (
                    filteredList.map((item: Notification, index) => (
                        <ListItem.Accordion
                            key={index + item.time}
                            content={
                                <>
                                    <Icon name="information-box-outline" size={24} color="#337ab7" />
                                    <ListItem.Content style={{marginLeft: 10}}>
                                        <ListItem.Title style={styles.title}>调课提醒：{item.course}</ListItem.Title>
                                        <ListItem.Subtitle style={styles.subtitle}>{item.time}</ListItem.Subtitle>
                                    </ListItem.Content>
                                </>
                            }
                            isExpanded={expandedIndex === index}
                            onPress={() => {
                                setExpandedIndex(expandedIndex === index ? null : index);
                                ToastAndroid.show("操作",ToastAndroid.SHORT);
                            }}>
                            <View
                                style={[
                                    styles.expandedContainer,
                                    {
                                        backgroundColor: theme.colors.background,
                                        borderTopColor: "#eee",
                                    },
                                ]}>
                                <ChangeDetail label="教师" oldValue={item.oldTeacher} newValue={item.newTeacher} />
                                <ChangeDetail label="周次" oldValue={item.oldWeek} newValue={item.newWeek} />
                                <ChangeDetail
                                    label="星期"
                                    oldValue={`星期${item.oldWeekday}`}
                                    newValue={`星期${item.newWeekday}`}
                                />
                                <ChangeDetail
                                    label="节次"
                                    oldValue={`${item.oldSection}节`}
                                    newValue={`${item.newSection}节`}
                                />
                                <ChangeDetail label="地点" oldValue={item.oldPlace} newValue={item.newPlace} />
                                <Text>{`原文：${item.text}`}</Text>
                            </View>
                        </ListItem.Accordion>
                    ))
                )}
            </ScrollView>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    filterContainer: {
        flexDirection: "row",
        justifyContent: "space-between",
        alignItems: "center",
        paddingHorizontal: 15,
        paddingVertical: 20,
    },
    filterText: {
        fontSize: 16,
    },
    title: {
        fontWeight: "bold",
        fontSize: 16,
    },
    subtitle: {
        fontSize: 12,
        color: "#888",
    },
    expandedContainer: {
        paddingHorizontal: 26,
        paddingVertical: 20,
        borderTopWidth: 1,
    },
    detailRow: {
        flexDirection: "row",
        alignItems: "center",
        marginBottom: 8,
    },
    label: {
        width: 50,
        fontSize: 14,
    },
    changeContainer: {
        flexDirection: "row",
        alignItems: "center",
    },
    oldValue: {
        fontSize: 14,
        color: "#999",
        textDecorationLine: "line-through",
    },
    newValue: {
        fontSize: 14,
        color: "green",
        fontWeight: "bold",
    },
});
