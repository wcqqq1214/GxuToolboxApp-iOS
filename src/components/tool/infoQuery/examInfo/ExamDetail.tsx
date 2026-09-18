import {ExamInfoParsed} from "@/type/infoQuery/exam/examInfo.ts";
import {StyleSheet, ToastAndroid, View, ViewProps} from "react-native";
import {useTheme} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";
import Clipboard from "@react-native-clipboard/clipboard";
import React, {createContext, useContext, useState} from "react";
import {Color} from "@/shared/color.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {Icon, UnJsonEditor, UnPressable, UnText} from "@/components/un-ui";
import {Pos} from "@/js/pos.ts";
import {parseExamTime} from "@/features/examInfo/utils/timeParser.ts";
import moment from "moment";
import {ExamInfoClass} from "@/class/jw/exam.ts";

const ExamContext = createContext<ExamInfoClass | null>(null);

interface Props extends ViewProps {
    examInfo: ExamInfoClass;
}

function copy(value: string, tip: string) {
    Clipboard.setString(value);
    ToastAndroid.show(tip, ToastAndroid.SHORT);
}

export function ExamDetail(props: Props) {
    const {store} = useUserConfig();
    const devMode = store(s => s.devMode);

    return (
        <ExamContext.Provider value={props.examInfo}>
            <Flex {...props} gap={10} direction="column">
                <ExamInfoCard />
                <Flex justify="center">
                    <UnText>点击属性，复制到剪切板</UnText>
                </Flex>
                <Flex gap={10}>
                    <ExamPropItem prop="courseName" label="课程名称" />
                    <ExamPropItem prop="examName" label="考试名称" />
                </Flex>
                <Flex gap={10}>
                    <ExamPropItem
                        prop="examTime"
                        label="考试时间"
                        valueRender={v => {
                            const date = v.slice(0, 10);
                            const time = v.match(/(?<=\().*?(?=\))/)?.[0] ?? "";
                            const {status} = parseExamTime(v);
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
                    <ExamPropItem prop="venueName" label="考试地点" />
                </Flex>
                <Flex gap={10}>
                    <ExamPropItem prop="seat" label="座位号" />
                    <ExamPropItem prop="examMethod" label="考察方式" />
                    <ExamPropItem prop="credits" label="学分" />
                </Flex>
                {devMode && <ExamDebugCard />}
            </Flex>
        </ExamContext.Provider>
    );
}

function ExamInfoCard() {
    const exam = useContext(ExamContext)!;
    const {theme} = useTheme();

    const styles = StyleSheet.create({
        card: {
            padding: 6,
            borderRadius: 4,
            backgroundColor: Color(theme.colors.primary).setAlpha(theme.mode === "light" ? 0.15 : 0.1).rgbaString,
        },
    });
    return (
        <View style={styles.card}>
            <UnText weight="bold" size={16}>
                {exam.transformed.courseName} · {exam.transformed.examName}
            </UnText>
            <UnText size={12} color={theme.colors.grey1}>
                {exam.transformed.examTime}，{exam.transformed.venueName}&lt;{exam.transformed.seat || "-"}&gt;
            </UnText>
        </View>
    );
}

function ExamDebugCard() {
    const exam = useContext(ExamContext);
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
                        查看考试数据
                    </UnText>
                </Flex>
            </UnPressable>
            <UnJsonEditor.Modal readOnly visible={modalOpen} onClose={() => setModalOpen(false)} value={exam} />
        </Flex>
    );
}

function ExamPropItem(props: {
    prop: keyof ExamInfoParsed;
    label: string;
    labelRender?: (value: string, item: ExamInfoClass) => React.ReactNode;
    valueRender?: (value: string, item: ExamInfoClass) => React.ReactNode;
    onClick?: (value: string, item: ExamInfoClass) => void;
}) {
    const exam = useContext(ExamContext)!;
    const {theme} = useTheme();

    const styles = StyleSheet.create({
        card: {
            padding: 6,
            borderRadius: 4,
            backgroundColor: Color(theme.colors.grey5).setAlpha(theme.mode === "light" ? 0.5 : 0.3).rgbaString,
        },
    });
    const value = (exam.transformed[props.prop] ?? "").toString();
    const labelNode = props.labelRender ? (
        props.labelRender(value, exam)
    ) : props.prop === "venueName" ? (
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
        props.valueRender(value, exam)
    ) : (
        <UnText numberOfLines={4}>{value || "-"}</UnText>
    );
    return (
        <UnPressable
            style={{flex: 1}}
            onPress={() =>
                props.onClick !== undefined
                    ? props.onClick(value, exam)
                    : copy(value || "-", "复制" + props.label + "成功")
            }>
            <Flex direction="column" style={styles.card} gap={4} align="flex-start">
                {labelNode}
                {valueNode}
            </Flex>
        </UnPressable>
    );
}
