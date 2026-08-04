import {Dimensions, ScrollView, StyleSheet, View} from "react-native";
import {teacherInfoApi} from "@/js/info/teacherInfo.ts";
import {Divider, Image, useTheme} from "@rneui/themed";
import Clipboard from "@react-native-clipboard/clipboard";
import React, {useEffect, useState} from "react";
import {usePagerView} from "react-native-pager-view";
import {DetailResData, SimpleTeacherInfo} from "@/type/api/teacherInfo/info.ts";
import {Flex, UnBottomSheet, UnCard, UnPressable, UnText, vh} from "@/components/un-ui";
import {Color} from "@/shared/color.ts";
import {CollapsedInfo} from "@/components/tool/infoQuery/courseSchedule/CollapsedInfo.tsx";

type Props = {
    isVisible: boolean;
    name: string;
    infoList: SimpleTeacherInfo[];
    openPage: number;
    onClose: () => void;
};

export function TeacherInfoSheet(props: Props) {
    const {theme} = useTheme();
    const [selectedTeacher, setSelectedTeacher] = useState<SimpleTeacherInfo>();
    const pagerView = usePagerView({pagesAmount: 2});

    useEffect(() => {
        if (!props.isVisible) return;
        pagerView.activePage = props.openPage;
        if (props.infoList.length === 1) {
            setSelectedTeacher(props.infoList[0]);
        }
        pagerView.ref.current?.setPage(props.openPage);
    }, [props.openPage, props.infoList, props.isVisible]);

    return (
        <UnBottomSheet
            isVisible={props.isVisible}
            onBackdropPress={() => {
                props.onClose?.();
            }}
            containerStyle={{height: vh(80), padding: 0}}>
            <View
                style={{
                    flexDirection: "row",
                    justifyContent: "space-between",
                    paddingHorizontal: 16,
                    paddingVertical: 8,
                    borderBottomColor: theme.colors.grey4,
                    borderBottomWidth: 1,
                }}>
                <UnText size={18}>{pagerView.activePage === 0 ? "检索到以下教师信息" : "教师个人信息"}</UnText>
                {pagerView.activePage !== 0 && (
                    <UnPressable
                        onPress={function () {
                            pagerView.ref.current?.setPage(0);
                        }}>
                        <UnText size={16}>返回</UnText>
                    </UnPressable>
                )}
            </View>
            <pagerView.AnimatedPagerView
                ref={pagerView.ref}
                style={{width: "100%", height: "100%"}}
                initialPage={props.openPage}
                overScrollMode="never"
                orientation="horizontal"
                scrollEnabled={false}
                onPageSelected={pagerView.onPageSelected}>
                <View key="0" collapsable={false} style={{width: "100%"}}>
                    <TeacherInfoList
                        onSelect={teacher => {
                            setSelectedTeacher(teacher);
                            pagerView.ref.current?.setPage(1);
                        }}
                        list={props.infoList}
                    />
                </View>
                <View key="1" collapsable={false} style={{width: "100%"}}>
                    {selectedTeacher && (
                        <TeacherDetailInfo
                            onBack={() => {
                                pagerView.ref.current?.setPage(0);
                            }}
                            name={selectedTeacher.XM}
                            school={selectedTeacher.dwmc}
                        />
                    )}
                </View>
            </pagerView.AnimatedPagerView>
        </UnBottomSheet>
    );
}

type listProps = {
    onSelect: (teacher: SimpleTeacherInfo) => void;
    list: SimpleTeacherInfo[];
};

function TeacherInfoList(props: listProps) {
    const iconUrl = "https://prof.gxu.edu.cn/images/icon-teacher.jpg";

    const {theme} = useTheme();

    return (
        <ScrollView>
            {props.list ? (
                props.list.map((item, index) => (
                    <UnPressable
                        style={{marginTop: 8, marginHorizontal: 4}}
                        onPress={() => {
                            props.onSelect(item);
                        }}>
                        <UnCard>
                            <Flex gap={8} align="flex-start">
                                <Image
                                    source={{uri: item.pic ? item.pic : iconUrl}}
                                    style={{width: 60, height: 80, borderRadius: 4}}
                                />
                                <View style={{flexDirection: "column", gap: 6, flex: 1}}>
                                    <UnText size={16}>{item.XM}</UnText>
                                    <UnText size={12}>{item.dwmc}</UnText>
                                </View>
                            </Flex>
                        </UnCard>
                    </UnPressable>
                ))
            ) : (
                <UnText size={16}>暂无信息</UnText>
            )}
        </ScrollView>
    );
}

type infoProps = {
    name: string;
    school: string;
    onBack: () => void;
};

function TeacherDetailInfo(props: infoProps) {
    const {theme} = useTheme();
    const iconUrl = "https://prof.gxu.edu.cn/images/icon-teacher.jpg";
    const [teacherInfo, setTeacherInfo] = useState<DetailResData>();

    const {width: screenWidth, height: screenHeight} = Dimensions.get("window");
    const style = StyleSheet.create({
        sheetContainerStyle: {
            paddingVertical: 16,
            paddingHorizontal: 12,
            width: screenWidth,
        },
        detailInfoContainer: {
            flexDirection: "column",
        },
        image: {
            width: screenWidth * 0.24,
            height: screenHeight * 0.16,
            borderRadius: 4,
        },
        eduItem: {
            backgroundColor: Color(theme.colors.primary).setAlpha(0.3).rgbaString,
            paddingHorizontal: 4,
            padding: 2,
            borderRadius: 4,
        },
        rowContainer: {
            flexDirection: "row",
            gap: 10,
        },
        rowBetween: {
            marginBottom: 12,
            height: 24,
            flexDirection: "row",
            justifyContent: "space-between",
        },
        columContainer: {
            flexDirection: "column",
            gap: 6,
        },
    });
    const dataList = [
        {
            label: "指导学科",
            value:
                teacherInfo?.baseInfo.zdxkChs.length > 0
                    ? teacherInfo?.baseInfo.zdxkChs.map(item => Object.values(item).join("、")).join("\n")
                    : "",
        },
        {label: "个人简介", value: teacherInfo?.largeMsg.zyxxjx},
        {label: "主讲课程", value: teacherInfo?.largeMsg.zyyjskc},
        {label: "主持（参与）的主要科研项目", value: teacherInfo?.largeMsg.zckyxm},
        {label: "主要研究方向", value: teacherInfo?.largeMsg.zyyjfx},
        {
            label: "取得的主要成果",
            value: [teacherInfo?.largeMsg?.lw, teacherInfo?.largeMsg?.zz, teacherInfo?.largeMsg?.zl]
                .filter(Boolean)
                .join("\n"),
        },
        {label: "荣誉与获奖", value: teacherInfo?.largeMsg.ryyhj},
        {label: "招生信息", value: teacherInfo?.largeMsg.zsxx},
        {label: "学术兼职", value: teacherInfo?.largeMsg.xsjz},
    ];

    function copy(value: string, tip: string) {
        Clipboard.setString(value);
    }

    async function getDetailInfo() {
        const res = await teacherInfoApi.getDetailInfo(props.name, props.school);
        const info = res.resData;
        setTeacherInfo(info);
    }

    useEffect(() => {
        getDetailInfo();
    }, [props.name, props.school]);

    return (
        <ScrollView contentContainerStyle={style.sheetContainerStyle}>
            <Flex gap={8} align="flex-start">
                <Image source={{uri: teacherInfo?.baseInfo.pic || iconUrl}} style={style.image} />
                <View style={{flex: 1}}>
                    <View style={style.columContainer}>
                        <Flex gap={4} align="center">
                            <UnText size={22} style={{fontWeight: "bold"}}>
                                <UnPressable
                                    onPress={function () {
                                        return copy(teacherInfo?.baseInfo.XM ?? "", "复制姓名成功");
                                    }}>
                                    <UnText size={22} style={{fontWeight: "bold"}}>
                                        {teacherInfo?.baseInfo.XM}
                                    </UnText>
                                </UnPressable>
                            </UnText>
                            {teacherInfo?.baseInfo.zhicheng && (
                                <UnPressable
                                    onPress={function () {
                                        return copy(teacherInfo?.baseInfo.zhicheng ?? "", "复制职称成功");
                                    }}>
                                    <UnText
                                        size={14}
                                        style={style.eduItem}
                                        color={Color.mix(theme.colors.primary, theme.colors.black, 0.3).rgbaString}>
                                        {teacherInfo?.baseInfo.zhicheng}
                                    </UnText>
                                </UnPressable>
                            )}
                            {teacherInfo?.baseInfo.topedu && teacherInfo.baseInfo.ZHXWMC && (
                                <UnPressable
                                    onPress={function () {
                                        return copy(
                                            `${teacherInfo?.baseInfo.ZHXWMC} | ${teacherInfo?.baseInfo.topedu}`,
                                            "复制学历学位成功",
                                        );
                                    }}>
                                    <UnText
                                        size={14}
                                        style={style.eduItem}
                                        color={Color.mix(theme.colors.primary, theme.colors.black, 0.3).rgbaString}>
                                        {teacherInfo?.baseInfo.ZHXWMC} | {teacherInfo?.baseInfo.topedu}
                                    </UnText>
                                </UnPressable>
                            )}
                        </Flex>
                        <Flex gap={4}>
                            <UnText size={14}>{teacherInfo?.baseInfo.XBM === "1" ? "男" : "女"}</UnText>
                            <UnText size={14}>{teacherInfo?.baseInfo.zzmm ?? "暂无政治面貌信息"}</UnText>
                        </Flex>
                        <Flex align="flex-start">
                            <UnText size={14}>所在单位：</UnText>
                            <UnPressable
                                style={{flex: 1}}
                                onPress={function () {
                                    return copy(teacherInfo?.baseInfo.forEditDwmc ?? "", "复制所在单位成功");
                                }}>
                                <UnText size={14}>{teacherInfo?.baseInfo.forEditDwmc}</UnText>
                            </UnPressable>
                        </Flex>
                        <Flex>
                            <UnText size={14}>邮政编码：</UnText>
                            <UnPressable
                                onPress={function () {
                                    return copy(teacherInfo?.baseInfo.yzbm ?? "", "复制邮政编码成功");
                                }}>
                                <UnText size={14}>{teacherInfo?.baseInfo.yzbm ?? "无"}</UnText>
                            </UnPressable>
                        </Flex>
                        <Flex>
                            <UnText size={14}>邮箱：</UnText>
                            <UnPressable
                                style={{flex: 1}}
                                onPress={function () {
                                    return copy(teacherInfo?.baseInfo.email?.trim() ?? "", "复制邮箱成功");
                                }}>
                                <UnText size={14}>{teacherInfo?.baseInfo.email?.trim() || "无"}</UnText>
                            </UnPressable>
                        </Flex>
                    </View>
                </View>
            </Flex>
            <Divider orientation={"horizontal"} />
            <View style={{marginBottom: vh(5)}}>
                {dataList.map((item, index) => (
                    <CollapsedInfo label={item.label}>
                        <UnText>{item.value?.trim() || "暂无信息"}</UnText>
                    </CollapsedInfo>
                ))}
            </View>
        </ScrollView>
    );
}
