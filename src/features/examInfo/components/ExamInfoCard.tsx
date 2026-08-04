import {StyleSheet, View} from "react-native";
import {Card, Text, useTheme} from "@rneui/themed";
import dayjs from "dayjs";
import Flex from "@/components/un-ui/Flex.tsx";
import {Icon} from "@/components/un-ui";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {ExamStatus} from "@/features/examInfo/utils/timeParser.ts";

interface Props {
    item: ExamWithMeta;
}

/** 判断 date 是否为有效的 dayjs 实例（存储反序列化后会丢失原型变成 {}） */
function isValidDayjs(d: unknown): d is dayjs.Dayjs {
    return d != null && typeof (d as any).isValid === "function" && (d as dayjs.Dayjs).isValid();
}

/** 计算距开考的倒计时文案，单位天 */
function getCountdownText(date: dayjs.Dayjs | null): string | null {
    if (!isValidDayjs(date)) return null;
    const now = dayjs();
    const diffDays = date.startOf("day").diff(now.startOf("day"), "day");
    if (diffDays < 0) return null; // 已过
    if (diffDays === 0) return "今日开考";
    if (diffDays === 1) return "明日开考";
    return `${diffDays}天后`;
}

const StatusBadge = ({item}: {item: ExamWithMeta}) => {
    const {theme} = useTheme();
    const {status, date} = item;

    const baseConfig: Record<ExamStatus, {text: string; color: string}> = {
        upcoming: {text: "即将开考", color: theme.colors.success},
        past: {text: "已结束", color: theme.colors.grey3},
        tbd: {text: "时间未知", color: theme.colors.warning},
    };

    // upcoming 且距开考 ≤ 3 天：用倒计时文案 + 醒目色
    const countdown = status === "upcoming" ? getCountdownText(date) : null;
    const isUrgent = status === "upcoming" && countdown !== null;

    const text = isUrgent ? countdown! : baseConfig[status]?.text;
    const color = isUrgent ? theme.colors.error : (baseConfig[status]?.color ?? theme.colors.grey2);

    return (
        <View
            style={{
                position: "absolute",
                top: -1,
                right: -1,
                backgroundColor: color,
                paddingHorizontal: 8,
                paddingVertical: 3,
                borderTopRightRadius: 8,
                borderBottomLeftRadius: 8,
            }}>
            <Text style={{color: "white", fontSize: 12, fontWeight: "bold"}}>{text}</Text>
        </View>
    );
};

const InfoRow = ({icon, label, value}: {icon: string; label: string; value: string}) => (
    <Flex align="center" gap={10} style={{marginVertical: 5}}>
        <Icon name={icon as any} size={16} color={"gray"} />
        <Text style={{color: "gray", width: 70, fontSize: 16}}>{label}:</Text>
        <Text style={{flex: 1, fontWeight: "bold", fontSize: 16}}>{value}</Text>
    </Flex>
);

export const ExamInfoCard = ({item}: Props) => {
    const {theme} = useTheme();

    const styles = StyleSheet.create({
        cardContainer: {
            borderRadius: 4,
            margin: 0,
            padding: 0,
            // past 状态整体弱化
            opacity: item.status === "past" ? 0.6 : 1,
        },
        header: {
            padding: 10,
            borderBottomWidth: 1,
            borderBottomColor: theme.colors.divider,
        },
        body: {
            padding: 10,
        },
        footer: {
            padding: 10,
            backgroundColor: theme.colors.grey5,
            borderBottomLeftRadius: 4,
            borderBottomRightRadius: 4,
        },
    });

    // 时间格式化：优先用解析出的 dayjs，失败兜底原串
    const timeText = isValidDayjs(item.date) ? `${item.date.format("MM月DD日 HH:mm")}` : item.time || "时间未定";

    return (
        <Card containerStyle={styles.cardContainer}>
            <StatusBadge item={item} />
            <View style={styles.header}>
                <Text h4 style={{textAlign: "center"}}>
                    {item.course.length > 10 ? item.course.slice(0, 10) + "\n" + item.course.slice(10) : item.course}
                </Text>
            </View>
            <View style={styles.body}>
                <InfoRow icon="clock-outline" label="考试时间" value={timeText} />
                <InfoRow icon="office-building-marker-outline" label="考试地点" value={item.classroom} />
                {item.status !== "past" && <InfoRow icon="seat-outline" label="座位号" value={item.seat || "未知"} />}
            </View>
            <View style={styles.footer}>
                <Text style={{color: theme.colors.grey2, fontSize: 12}}>{item.type}</Text>
            </View>
        </Card>
    );
};
