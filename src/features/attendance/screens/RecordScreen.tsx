import {Modal, ScrollView, StyleSheet, Text, TouchableOpacity, View} from "react-native";
import {Divider, Switch, useTheme} from "@rneui/themed";
import moment from "moment";
import {useRecord} from "@/features/attendance/hooks/useRecord.ts";
import {Icon, UnRefreshControl} from "@/components/un-ui";
import {RecordCard} from "@/features/attendance/components/RecordCard.tsx";
import {useState} from "react";

function formatRecordDate(date: string) {
    const parsed = moment(date, ["YYYY-MM-DD", "YYYY-M-D"], true);
    return parsed.isValid() ? `${parsed.format("M月D日")} · 周${"日一二三四五六"[parsed.day()]}` : date;
}
type SelectedTerm = {
    year: number;
    term: 1 | 2;
};

interface Props {
    selectedTerm: SelectedTerm | null;
}

export function RecordScreen({selectedTerm}: Props) {
    const {records, loading, refresh} = useRecord(selectedTerm);
    const {theme} = useTheme();
    const [onlyAbnormal, setOnlyAbnormal] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const recordsByDate = new Map<string, typeof records>();

    const abnormalCount = records.filter(record => record.statusCode === 2 || record.statusCode === 4).length;

    for (const record of records) {
        if (
            onlyAbnormal &&
            record.statusCode !== 2 &&
            record.statusCode !== 4 &&
            moment(record.date).isBefore(moment().subtract(7, "days"), "day")
        ) {
            continue;
        }

        const items = recordsByDate.get(record.date) ?? [];
        items.push(record);
        recordsByDate.set(record.date, items);
    }

    const styles = StyleSheet.create({
        list: {
            paddingHorizontal: 16,
            paddingBottom: 24,
        },
        group: {
            marginTop: 16,
        },
        dateHeader: {
            flexDirection: "row",
            alignItems: "center",
            gap: 8,
            marginBottom: 8,
        },
        dateMarker: {
            width: 3,
            height: 14,
            borderRadius: 2,
        },
        dateText: {
            fontSize: 13,
            fontWeight: "600",
        },
        groupBody: {
            borderRadius: 12,
            overflow: "hidden",
        },
        filterRow: {
            marginHorizontal: 16,
            marginTop: 8,
            paddingHorizontal: 14,
            paddingVertical: 10,
            borderRadius: 10,
            flexDirection: "row",
            alignItems: "center",
            justifyContent: "space-between",
        },
        overlay: {
            flex: 1,
            backgroundColor: "rgba(0,0,0,0.4)",
            justifyContent: "center",
            alignItems: "center",
            padding: 16,
        },
        modalCard: {
            width: "88%",
            maxWidth: "90%",
            borderRadius: 14,
            backgroundColor: theme.colors.white,
            paddingVertical: 16,
            paddingHorizontal: 16,
            shadowColor: "#000",
            shadowOpacity: 0.2,
            shadowRadius: 12,
            shadowOffset: {width: 0, height: 6},
            elevation: 6,
            maxHeight: "80%",
        },
        modalTitle: {
            fontSize: 20,
            fontWeight: "bold",
            marginBottom: 10,
            color: theme.colors.black,
            textAlign: "center",
        },
        modalContent: {
            fontSize: 16,
            marginBottom: 10,
            color: theme.colors.black,
        },
        modalCloseButton: {
            fontSize: 16,
            fontWeight: "bold",
            color: theme.colors.primary,
            textAlign: "center",
            marginTop: 10,
        },
        filterHeader: {
            flexDirection: "row",
            alignItems: "center",
            gap: 8,
        },
        filterTitle: {
            fontSize: 15,
            fontWeight: "600",
        },
        helpButton: {
            flexDirection: "row",
            alignItems: "center",
            gap: 4,
            paddingVertical: 4,
        },
        helpText: {
            fontSize: 12,
        },
        filterHint: {
            marginTop: 2,
            fontSize: 12,
        },
    });

    return (
        <>
            <View style={{flex: 1}}>
                <View style={[styles.filterRow, {backgroundColor: theme.colors.white}]}>
                    <View>
                        <View style={styles.filterHeader}>
                            <Text style={[styles.filterTitle, {color: theme.colors.black}]}>仅看异常与近一周记录</Text>

                            <TouchableOpacity
                                style={styles.helpButton}
                                accessibilityRole="button"
                                accessibilityLabel="查看异常考勤说明"
                                onPress={() => setShowModal(true)}>
                                <Text style={[styles.helpText, {color: theme.colors.primary}]}>迟到与踩点</Text>
                                <Icon
                                    type="fontawesome"
                                    name="circle-question"
                                    color={theme.colors.primary}
                                    size={14}
                                />
                            </TouchableOpacity>
                        </View>

                        <Text style={[styles.filterHint, {color: theme.colors.grey2}]}>
                            本学期共记录 {records.length} 次考勤，其中异常 {abnormalCount} 次
                        </Text>
                    </View>

                    <Switch
                        value={onlyAbnormal}
                        onValueChange={setOnlyAbnormal}
                        accessibilityLabel="仅看异常考勤记录"
                        disabled={abnormalCount === 0}
                    />
                </View>
                <Divider />
                <ScrollView refreshControl={<UnRefreshControl refreshing={loading} onRefresh={refresh} />}>
                    <View style={styles.list}>
                        {Array.from(recordsByDate, ([date, items]) => (
                            <View key={date} style={styles.group}>
                                <View style={styles.dateHeader}>
                                    <Text style={[styles.dateText, {color: theme.colors.grey2}]}>
                                        {formatRecordDate(date)}
                                    </Text>
                                </View>
                                <View style={[styles.groupBody, {backgroundColor: theme.colors.white}]}>
                                    {items.map((record, index) => (
                                        <RecordCard
                                            key={`${record.courseName}-${record.periodRange}-${index}`}
                                            record={record}
                                            showDivider={index < items.length - 1}
                                        />
                                    ))}
                                </View>
                            </View>
                        ))}
                    </View>
                </ScrollView>
            </View>
            <Modal visible={showModal} animationType="fade" transparent>
                <View style={styles.overlay}>
                    <View style={styles.modalCard}>
                        <Text style={styles.modalTitle}>考勤说明</Text>
                        <ScrollView>
                            <Text style={styles.modalContent}>
                                第一、二节正常签到：7：00-8：00{"\n"}
                                第一、二节迟到时间：8：00-8：10{"\n"}
                                {"\n"}
                                第三、四节正常签到：9：41-10：00{"\n"}
                                第三、四节迟到时间：10：00-10：10 {"\n"}
                                {"\n"}
                                第五、六节正常签到：13：30-14：30{"\n"}
                                第五、六节迟到时间：14：30-14：40{"\n"}
                                {"\n"}
                                第七、八节正常签到：16：06-16：25{"\n"}
                                第七、八节迟到时间：16：25-16：35{"\n"}
                                {"\n"}
                                第九、十节正常签到：18：40-19：40{"\n"}
                                第九、十节迟到时间：19：40-19：50{"\n"}
                                {"\n"}
                                短时间内查询信息会显示旷课，不用担心，数据更新可能延迟，只要保证正常打卡就可以。节假日调课引起的全天未到记录，可以忽视。
                            </Text>
                        </ScrollView>
                        <TouchableOpacity onPress={() => setShowModal(false)}>
                            <Text style={styles.modalCloseButton}>关闭</Text>
                        </TouchableOpacity>
                    </View>
                </View>
            </Modal>
        </>
    );
}
