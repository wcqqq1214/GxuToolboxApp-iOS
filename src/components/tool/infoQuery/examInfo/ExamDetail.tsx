import {StyleSheet, ToastAndroid, ViewProps} from "react-native";
import {useTheme} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";
import Clipboard from "@react-native-clipboard/clipboard";
import React, {useState} from "react";
import {Color} from "@/shared/color.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {Icon, UnJsonEditor, UnPressable, UnText} from "@/components/un-ui";
import {Pos} from "@/js/pos.ts";
import {parseExamTime} from "@/features/examInfo/utils/timeParser.ts";
import moment from "moment";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {ExamInfoCard} from "@/features/examInfo/components/ExamInfoCard.tsx";

/** 详情层里可点击复制的字段，直接用后端代理接口的字段名 */
type ExamPropKey = "course" | "type" | "time" | "classroom" | "seat";

interface Props extends ViewProps {
    exam: ExamWithMeta;
}

function copy(value: string, tip: string) {
    Clipboard.setString(value);
    ToastAndroid.show(tip, ToastAndroid.SHORT);
}

export function ExamDetail({exam, ...rest}: Props) {
    const {store} = useUserConfig();
    const devMode = store(s => s.devMode);

    return (
        <Flex {...rest} gap={10} direction="column">
            {/* 与考试信息页共用同一张卡片，保证两处字段展示一致 */}
            <Flex direction="column" align="stretch">
                <ExamInfoCard item={exam} />
            </Flex>
            <Flex justify="center">
                <UnText>点击属性，复制到剪切板</UnText>
            </Flex>
            <Flex gap={10}>
                <ExamPropItem exam={exam} prop="course" label="课程名称" />
                <ExamPropItem exam={exam} prop="type" label="考试名称" />
            </Flex>
            <Flex gap={10}>
                <ExamPropItem
                    exam={exam}
                    prop="time"
                    label="考试时间"
                    valueRender={v => {
                        const {status} = parseExamTime(v);
                        // 时间串解析不出来（例如缺 (HH:mm-HH:mm)）时整串兜底，避免算出 NaN 天数
                        if (status === "tbd") {
                            return <UnText numberOfLines={4}>{v || "-"}</UnText>;
                        }
                        const date = v.slice(0, 10);
                        const time = v.match(/(?<=\().*?(?=\))/)?.[0] ?? "";
                        const diff = moment(date).diff(moment(), "days");
                        const suffix = status === "past" ? "已结束" : diff === 0 ? "今天" : `${diff}天后`;
                        return (
                            <Flex direction="column" gap={2} align="flex-start">
                                <UnText>
                                    {date}（{suffix}）
                                </UnText>
                                <UnText>{time || "-"}</UnText>
                            </Flex>
                        );
                    }}
                />
                <ExamPropItem exam={exam} prop="classroom" label="考试地点" />
            </Flex>
            <Flex gap={10}>
                <ExamPropItem exam={exam} prop="seat" label="座位号" />
            </Flex>
            {devMode && <ExamDebugCard exam={exam} />}
        </Flex>
    );
}

function ExamDebugCard({exam}: {exam: ExamWithMeta}) {
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
                    <Icon name="console" size={16} />
                    <UnText weight="bold" size={16}>
                        查看考试数据
                    </UnText>
                </Flex>
            </UnPressable>
            <UnJsonEditor.Modal readOnly visible={modalOpen} onClose={() => setModalOpen(false)} value={exam} />
        </Flex>
    );
}

function ExamPropItem(props: {
    exam: ExamWithMeta;
    prop: ExamPropKey;
    label: string;
    valueRender?: (value: string) => React.ReactNode;
}) {
    const {theme} = useTheme();

    const styles = StyleSheet.create({
        card: {
            padding: 6,
            borderRadius: 4,
            backgroundColor: Color(theme.colors.grey5).setAlpha(theme.mode === "light" ? 0.5 : 0.3).rgbaString,
        },
    });
    const value = (props.exam[props.prop] ?? "").toString();
    const labelNode =
        props.prop === "classroom" ? (
            <UnPressable onPress={() => Pos.parseAndSearchInMap(value)}>
                <Flex gap={5} align="center" inline>
                    <UnText weight="bold" size={16}>
                        {props.label}
                    </UnText>
                    <Icon
                        type="ionicons"
                        name="navigate"
                        color={Color.mix(theme.colors.primary, theme.colors.black).rgbaString}
                        size={16}
                    />
                </Flex>
            </UnPressable>
        ) : (
            <UnText weight="bold" size={16}>
                {props.label}
            </UnText>
        );
    const valueNode = props.valueRender ? (
        props.valueRender(value)
    ) : (
        <UnText numberOfLines={4}>{value || "-"}</UnText>
    );
    return (
        <UnPressable
            style={{flex: 1}}
            onPress={() => copy(value || "-", "复制" + props.label + "成功")}>
            <Flex direction="column" style={styles.card} gap={4} align="flex-start">
                {labelNode}
                {valueNode}
            </Flex>
        </UnPressable>
    );
}
