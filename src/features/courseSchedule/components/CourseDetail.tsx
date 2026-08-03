import {AdapterTheoryItem, CourseClass} from "@/class/jw/course.ts";
import {Image, Linking, StyleSheet, ToastAndroid, View, ViewProps} from "react-native";
import {Text, useTheme} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";
import Clipboard from "@react-native-clipboard/clipboard";
import React, {createContext, useContext, useEffect, useState} from "react";
import {Color} from "@/shared/color.ts";
import {useUserConfig} from "@/hooks/useUserConfig.ts";
import {TeacherInfoSheet} from "@/components/tool/infoQuery/courseSchedule/TeacherInfoSheet.tsx";
import {Icon, UnJsonEditor, UnPressable, UnText} from "@/components/un-ui";
import {useBlocksColor} from "@/features/courseSchedule/hooks/useBlocksColor.ts";
import {Pos} from "@/js/pos.ts";
import {SimpleTeacherInfo} from "@/type/api/teacherInfo/info.ts";
import {teacherInfoApi} from "@/js/info/teacherInfo.ts";
import {ExamInfoClass} from "@/class/jw/exam.ts";
import {parseExamTime} from "@/features/examInfo/utils/timeParser.ts";
import moment from "moment";

const CourseContext = createContext<AdapterTheoryItem | null>(null);

interface Props extends ViewProps {
    course: CourseClass;
    examInfo?: ExamInfoClass[];
    onExamPress?: (exam: ExamInfoClass) => void;
}

interface Info {
    label: string;
    key: keyof AdapterTheoryItem;
}

function copy(value: string, tip: string) {
    Clipboard.setString(value);
    ToastAndroid.show(tip, ToastAndroid.SHORT);
}

export function CourseDetail(props: Props) {
    const [visible, setVisible] = useState(false);

    const {theme} = useTheme();
    const {store} = useUserConfig();
    const devMode = store(s => s.devMode);
    const course = props.course._ori;

    const [teacherInfoList, setTeacherInfoList] = useState<SimpleTeacherInfo[]>([]);
    const name = course.teacher;

    const iconUrl = "https://prof.gxu.edu.cn/images/icon-teacher.jpg";

    useEffect(() => {
        teacherInfoApi.getBaseInfo(name, 1).then(res => {
            const filterData = res.resData.list.filter(item => item.XM.length === name.length);
            setTeacherInfoList(filterData);
        });
    }, [name]);
    return (
        <CourseContext.Provider value={course}>
            <Flex {...props} gap={10} direction="column">
                <CourseInfoCard />
                {props.examInfo?.length > 0 && (
                    <Flex justify="center" direction="column" gap={6}>
                        <Text>相关考试</Text>
                        {props.examInfo.map(exam => (
                            <CourseExamCard examInfo={exam} onPress={() => props.onExamPress?.(exam)} />
                        ))}
                    </Flex>
                )}
                <Flex justify="center">
                    <Text>点击属性，复制到剪切板</Text>
                </Flex>
                <Flex gap={10}>
                    <CoursePropItem prop="courseName" label="课程名称" />
                    <CoursePropItem
                        prop="venueName"
                        label="上课地点"
                        valueRender={(v, course) => <UnText>{course.building + v}</UnText>}
                        labelRender={v => (
                            <UnPressable onPress={() => Pos.parseAndSearchInMap(v)}>
                                <Flex gap={4} align="center" inline>
                                    <UnText weight="bold" size={16}>
                                        上课地点
                                    </UnText>
                                    <Icon
                                        type="Ionicon"
                                        name="navigate"
                                        color={Color.mix(theme.colors.primary, theme.colors.black).rgbaString}
                                        size={16}
                                    />
                                </Flex>
                            </UnPressable>
                        )}
                    />
                </Flex>
                <Flex gap={10}>
                    <CoursePropItem
                        prop="teacher"
                        label="上课教师"
                        valueRender={v => (
                            <Flex direction={"row"} gap={4}>
                                {teacherInfoList.length === 1 && (
                                    <Image
                                        style={{width: 20, height: 20, borderRadius: 999}}
                                        source={{uri: teacherInfoList[0]?.pic || iconUrl}}
                                    />
                                )}
                                <UnText>{v}</UnText>
                            </Flex>
                        )}
                        labelRender={() => (
                            <UnPressable onPress={() => setVisible(true)}>
                                <Flex gap={4} align="center" inline>
                                    <UnText weight="bold" size={16}>
                                        上课教师
                                    </UnText>
                                    <Icon
                                        name="magnify"
                                        color={Color.mix(theme.colors.primary, theme.colors.black).rgbaString}
                                        size={16}
                                    />
                                </Flex>
                            </UnPressable>
                        )}
                    />
                    <CoursePropItem prop="examMethod" label="考核方式" />
                    <CoursePropItem prop="credits" label="学分" />
                </Flex>
                <Flex gap={10}>
                    <CoursePropItem prop="enrollmentCount" label="选课人数" />
                    <CoursePropItem prop="seatCount" label="座位数" />
                    <CoursePropItem
                        prop="qqGroup"
                        label="QQ群"
                        labelRender={qq =>
                            qq.trim().length > 0 ? (
                                <Flex gap={4} align="center" inline>
                                    <UnText weight="bold" size={16}>
                                        QQ群
                                    </UnText>
                                    <Icon
                                        name="open-in-new"
                                        color={Color.mix(theme.colors.primary, theme.colors.black).rgbaString}
                                        size={16}
                                    />
                                </Flex>
                            ) : (
                                <UnText weight="bold" size={16}>
                                    QQ群
                                </UnText>
                            )
                        }
                        valueRender={qq => <UnText>{qq.trim() || "暂无"}</UnText>}
                        onClick={async qq => {
                            if (qq.trim()) {
                                const url = `mqqapi://card/show_pslcard?src_type=internal&version=1&uin=${qq}&card_type=group&source=qrcode`;
                                await Linking.openURL(url).catch(e => {
                                    console.error(e);
                                    ToastAndroid.show("无法直接跳转QQ，已将QQ群号复制至剪切板", ToastAndroid.SHORT);
                                    Clipboard.setString(qq);
                                });
                            }
                        }}
                    />
                </Flex>
                <TeacherInfoSheet
                    isVisible={visible}
                    name={course.teacher}
                    infoList={teacherInfoList}
                    onClose={() => setVisible(false)}
                    openPage={teacherInfoList.length === 1 ? 1 : 0}
                />
                {devMode && <CourseDebugCard />}
            </Flex>
        </CourseContext.Provider>
    );
}

function CourseInfoCard() {
    const course = useContext(CourseContext)!;
    const {theme} = useTheme();
    const {getColor} = useBlocksColor();

    const styles = StyleSheet.create({
        card: {
            padding: 6,
            borderRadius: 4,
            backgroundColor: Color(getColor({title: course.courseName})).setAlpha(theme.mode === "light" ? 0.5 : 0.3)
                .rgbaString,
        },
    });
    return (
        <View style={styles.card}>
            <UnText weight="bold" size={16}>
                {course.courseName}
            </UnText>
            <UnText size={12} color={theme.colors.grey1}>
                {course.venueName}，{course.teacher}，{course.courseCategory}，{course.examMethod}
                {" · "}
                {course.sectionRange}节，{course.weeks?.join(",")}
            </UnText>
        </View>
    );
}

function CourseExamCard({examInfo, onPress}: {examInfo: ExamInfoClass; onPress?: () => void}) {
    const exam = examInfo.transformed;
    const {theme} = useTheme();
    const {status} = parseExamTime(exam.examTime);
    const date = exam.examTime.slice(0, 10);
    const time = exam.examTime.match(/(?<=\().*?(?=\))/)?.[0] ?? "";
    const diff = moment(date).diff(moment(), "days");
    const suffix = status === "past" ? "已结束" : diff === 0 ? "今天" : `${diff}天后`;

    const styles = StyleSheet.create({
        card: {
            padding: 6,
            borderRadius: 4,
            width: "100%",
            backgroundColor: Color(theme.colors.primary).setAlpha(theme.mode === "light" ? 0.2 : 0.12).rgbaString,
        },
    });
    return (
        <UnPressable onPress={onPress} style={styles.card}>
            <UnText weight="bold" size={16}>
                {exam.examName}
            </UnText>
            <UnText size={12} color={theme.colors.grey1}>
                {date}（{suffix}）{time}，{exam.venueName}&lt;{exam.seat || "-"}&gt;
            </UnText>
        </UnPressable>
    );
}

function CourseDebugCard() {
    const course = useContext(CourseContext);
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
            <UnPressable
                onPress={function () {
                    return setModalOpen(true);
                }}>
                <Flex style={styles.card} justify="flex-start" gap={4}>
                    <Icon name="console" size={16} inline />
                    <UnText weight="bold" size={16}>
                        查看课程数据
                    </UnText>
                </Flex>
            </UnPressable>
            <UnJsonEditor.Modal readOnly visible={modalOpen} onClose={() => setModalOpen(false)} value={course} />
        </Flex>
    );
}

function CoursePropItem<K extends keyof AdapterTheoryItem>(props: {
    prop: K;
    label: string;
    labelRender?: (value: AdapterTheoryItem[K], item: AdapterTheoryItem) => React.ReactNode;
    valueRender?: (value: AdapterTheoryItem[K], item: AdapterTheoryItem) => React.ReactNode;
    onClick?: (value: AdapterTheoryItem[K], item: AdapterTheoryItem) => void;
}) {
    const course = useContext(CourseContext)!;
    const {theme} = useTheme();

    const styles = StyleSheet.create({
        card: {
            padding: 6,
            borderRadius: 4,
            backgroundColor: Color(theme.colors.grey5).setAlpha(theme.mode === "light" ? 0.5 : 0.3).rgbaString,
        },
    });
    const value = course[props.prop];
    const labelNode = props.labelRender ? (
        props.labelRender(value, course)
    ) : (
        <UnText weight="bold" size={16}>
            {props.label}
        </UnText>
    );
    const valueNode = props.valueRender ? (
        props.valueRender(value, course)
    ) : (
        <UnText numberOfLines={4}>{(value ?? "").toString() || "-"}</UnText>
    );
    return (
        <UnPressable
            style={{flex: 1}}
            onPress={function () {
                return props.onClick !== undefined
                    ? props.onClick(value, course)
                    : copy((value ?? "").toString() || "-", "复制" + props.label + "成功");
            }}>
            <Flex direction="column" style={styles.card} gap={4} align="flex-start">
                {labelNode}
                {valueNode}
            </Flex>
        </UnPressable>
    );
}
