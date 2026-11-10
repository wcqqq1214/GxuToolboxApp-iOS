import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {useTheme} from "@rneui/themed";
import {parseExamTime} from "@/features/examInfo/utils/timeParser.ts";
import {Color} from "@/shared/color.ts";
import {Flex, UnPressable, UnText} from "@/components/un-ui";
import moment from "moment";

export function CourseExamCard({examInfo, onPress}: {examInfo: ExamWithMeta; onPress?: () => void}) {
    const exam = examInfo;
    const {theme} = useTheme();
    const {status} = parseExamTime(exam.time);
    const date = exam.time.slice(0, 10);
    const time = exam.time.match(/(?<=\().*?(?=\))/)?.[0] ?? "";
    const diff = moment(date).diff(moment(), "days");

    const isPast = status === "past";
    const statusLabel = isPast ? "已结束" : diff === 0 ? "今天考试" : `${diff} 天后`;

    // 状态标签配色：已结束用中性灰，即将开始用主题色
    const badgeBg = isPast
        ? Color(theme.colors.grey4).setAlpha(0.3).rgbaString
        : Color(theme.colors.primary).setAlpha(0.18).rgbaString;
    const badgeColor = isPast ? theme.colors.grey1 : theme.colors.primary;

    const cardBg = Color(theme.colors.primary).setAlpha(
        theme.mode === "light" ? (isPast ? 0.04 : 0.08) : isPast ? 0.08 : 0.15,
    ).rgbaString;

    return (
        <UnPressable
            onPress={onPress}
            style={{
                width: "100%",
                paddingHorizontal: 12,
                paddingVertical: 10,
                borderRadius: 10,
                backgroundColor: cardBg,
                opacity: isPast ? 0.75 : 1,
            }}>
            {/* 顶栏：考试类型 + 状态倒计时标签 */}
            <Flex justify="space-between" align="center">
                <UnText weight="bold" size={15} color={isPast ? theme.colors.grey1 : theme.colors.black}>
                    {exam.type}
                </UnText>
                <Flex
                    style={{
                        paddingHorizontal: 6,
                        paddingVertical: 2,
                        borderRadius: 4,
                        backgroundColor: badgeBg,
                    }}>
                    <UnText size={11} weight="bold" color={badgeColor}>
                        {statusLabel}
                    </UnText>
                </Flex>
            </Flex>

            {/* 底栏：时间、地点、座位 */}
            <Flex justify="space-between" align="center" style={{marginTop: 6}}>
                <Flex gap={8} align="center">
                    <UnText size={12} color={theme.colors.grey1}>
                        {date} {time}
                    </UnText>
                    <UnText size={12} color={theme.colors.grey2}>
                        ·
                    </UnText>
                    <UnText size={12} color={theme.colors.grey1}>
                        {exam.classroom || "考场未定"}
                    </UnText>
                    {!!exam.seat && (
                        <UnText size={12} color={theme.colors.primary} weight="bold">
                            {exam.seat} 号座
                        </UnText>
                    )}
                </Flex>
            </Flex>
        </UnPressable>
    );
}
