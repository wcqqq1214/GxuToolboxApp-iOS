import {AdapterTheoryItem, CourseClass} from "@/class/jw/course.ts";
import {Image, Linking, ToastAndroid, View, ViewProps} from "react-native";
import {useTheme} from "@rneui/themed";
import Flex from "@/components/un-ui/Flex.tsx";
import React, {useState} from "react";
import {Color} from "@/shared/color.ts";
import {TeacherSheet} from "@/features/courseSchedule/components/sheets/TeacherSheet.tsx";
import {UnText} from "@/components/un-ui";
import {useLookup} from "@/features/teachersInfo/hooks/useLookup.ts";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import Clipboard from "@react-native-clipboard/clipboard";
import {Pos} from "@/js/pos.ts";
import {DetailActionButton, DetailRow} from "@/features/courseSchedule/components/sheets/DetailRow.tsx";
import {CourseExamCard} from "@/features/courseSchedule/components/sheets/CourseExamCard.tsx";

interface Props extends ViewProps {
    course: CourseClass | AdapterTheoryItem;
    examInfo?: ExamWithMeta[];
    onExamPress?: (exam: ExamWithMeta) => void;
}

function resolveSportsCollegeMapKeyword(location: string): string | null {
    if (location.includes("北")) {
        return "广西大学行健图书馆行健馆";
    }
    if (location.includes("西")) {
        return "广西大学西校园综合体育馆";
    }
    if (location.includes("东")) {
        return "广西大学东校园体育场";
    }
    return null;
}

export function CourseDetailSheet(props: Props) {
    const [visible, setVisible] = useState(false);

    const {theme} = useTheme();

    // TODO
    const course: AdapterTheoryItem = props.course instanceof CourseClass ? props.course._ori : props.course;
    const {enrollmentCount, seatCount, building, venueName} = course;

    const fullLocation = building + venueName;
    const isSportsCollege = fullLocation.includes("体育学院");

    const displayLocation = building.includes("体育学院") ? venueName : `${building} | ${venueName}`;

    const sportsCollegeMapKeyword = isSportsCollege ? resolveSportsCollegeMapKeyword(displayLocation) : null;

    const qqGroup = course.qqGroup?.trim();

    const occupancy = Number.isFinite(seatCount) && seatCount > 0 ? (enrollmentCount / seatCount) * 100 : NaN;
    const occupancyLabel = Number.isFinite(occupancy) && occupancy >= 0 ? `${occupancy.toFixed(2)}%` : "暂无";

    const {list: teacherInfoList} = useLookup(course.teacher);
    const teacherUnit = teacherInfoList[0]?.unit;

    const iconUrl = "https://prof.gxu.edu.cn/images/icon-teacher.jpg";
    return (
        <View>
            <Flex {...props} gap={10} direction="column">
                <Flex direction={"column"} justify={"flex-start"} align={"flex-start"} gap={8}>
                    <Flex inline align="flex-start" gap={10}>
                        <View
                            style={{
                                width: 3,
                                height: 18,
                                marginTop: 8,
                                borderRadius: 2,
                                backgroundColor: theme.colors.primary,
                            }}
                        />
                        <Flex direction="column" align="flex-start" gap={4}>
                            <UnText accessibilityRole="header" size={28} bold>
                                {course.courseName}
                            </UnText>
                            <UnText size={14} color={theme.colors.grey2}>
                                {course.credits} 学分 | {course.examMethod}
                            </UnText>
                        </Flex>
                    </Flex>
                    {props.examInfo && props.examInfo.length > 0 && (
                        <Flex justify="flex-start" align={"flex-start"} direction="column" gap={6}>
                            <UnText size={20} style={{fontWeight: "bold", marginTop: 8}}>
                                相关考试
                            </UnText>
                            {props.examInfo.map(exam => (
                                <CourseExamCard examInfo={exam} onPress={() => props.onExamPress?.(exam)} />
                            ))}
                        </Flex>
                    )}
                    <UnText size={20} style={{fontWeight: "bold", marginTop: 8}}>
                        任课教师
                    </UnText>
                    <Flex
                        inline
                        style={{
                            borderRadius: 18,
                            backgroundColor: Color(theme.colors.primary).setAlpha(theme.mode === "light" ? 0.08 : 0.15)
                                .rgbaString,
                        }}>
                        <Image
                            style={{width: 120, height: 120, borderRadius: 60, margin: 12}}
                            source={{uri: teacherInfoList[0]?.picUrl || iconUrl}}
                        />
                        <Flex
                            direction="column"
                            align="flex-start"
                            justify="center"
                            gap={4}
                            style={{paddingRight: 12, paddingVertical: 12}}>
                            <UnText bold size={20}>
                                {course.teacher}
                            </UnText>
                            {!!teacherUnit && (
                                <UnText size={13} color={theme.colors.grey2}>
                                    {teacherUnit}
                                </UnText>
                            )}
                            <DetailActionButton
                                icon="account-outline"
                                label="查看详情"
                                onPress={() => setVisible(true)}
                            />
                        </Flex>
                    </Flex>
                    <Flex
                        inline
                        direction="column"
                        align="stretch"
                        gap={14}
                        style={{marginTop: 28, paddingHorizontal: 4}}>
                        <DetailRow
                            icon="map-marker"
                            label="上课地点"
                            value={displayLocation}
                            action={{
                                icon: "navigation-variant",
                                label: "导航",
                                onPress: () =>
                                    sportsCollegeMapKeyword
                                        ? Pos.searchInMap(sportsCollegeMapKeyword)
                                        : Pos.parseAndSearchInMap(displayLocation),
                            }}
                        />
                        {!!qqGroup && (
                            <DetailRow
                                icon="qqchat"
                                label="课程 QQ 群"
                                value={qqGroup}
                                action={{
                                    icon: "share",
                                    label: "加群",
                                    onPress: async () => {
                                        const url = `mqqapi://card/show_pslcard?src_type=internal&version=1&uin=${qqGroup}&card_type=group&source=qrcode`;
                                        await Linking.openURL(url).catch(e => {
                                            console.error(e);
                                            ToastAndroid.show(
                                                "无法直接跳转QQ，已将QQ群号复制至剪切板",
                                                ToastAndroid.SHORT,
                                            );
                                            Clipboard.setString(qqGroup);
                                        });
                                    },
                                }}
                            />
                        )}
                        <DetailRow
                            icon="seat"
                            label="选课情况"
                            value={`${enrollmentCount} 人 / ${seatCount} 座位 · 理论满座率 ${occupancyLabel}`}
                        />
                    </Flex>
                </Flex>
                <TeacherSheet
                    isVisible={visible}
                    infoList={teacherInfoList}
                    onClose={() => setVisible(false)}
                    openPage={teacherInfoList.length === 1 ? 1 : 0}
                />
            </Flex>
        </View>
    );
}

// function CourseDebugCard() {
//     const course = useContext(CourseContext);
//     const {theme} = useTheme();
//     const [modalOpen, setModalOpen] = useState(false);
//
//     return (
//         <Flex>
//             <UnPressable
//                 onPress={function () {
//                     return setModalOpen(true);
//                 }}>
//                 <Flex
//                     justify="flex-start"
//                     gap={4}
//                     style={{
//                         padding: 6,
//                         borderRadius: 4,
//                         backgroundColor: Color(theme.colors.error).setAlpha(theme.mode === "light" ? 0.12 : 0.22)
//                             .rgbaString,
//                     }}>
//                     <Icon name="console" size={16} />
//                     <UnText weight="bold" size={16}>
//                         查看课程数据
//                     </UnText>
//                 </Flex>
//             </UnPressable>
//             <UnJsonEditor.Modal readOnly visible={modalOpen} onClose={() => setModalOpen(false)} value={course} />
//         </Flex>
//     );
// }
