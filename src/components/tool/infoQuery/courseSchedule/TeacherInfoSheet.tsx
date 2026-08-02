import {Dimensions, ScrollView, StyleSheet, View} from "react-native";
import {teacherInfoApi} from "@/js/info/teacherInfo.ts";
import {BottomSheet, Divider, Image, useTheme} from "@rneui/themed";
import React, {useEffect, useState} from "react";
import {usePagerView} from "react-native-pager-view";
import {DetailResData, SimpleTeacherInfo} from "@/type/api/teacherInfo/info.ts";
import {Flex, UnPressable, UnText, vh} from "@/components/un-ui";
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

    const style = StyleSheet.create({
        bottomSheetContainer: {
            height: vh(80),
            backgroundColor: theme.colors.background,
            borderTopLeftRadius: 8,
            borderTopRightRadius: 8,
            borderColor: Color.mix(theme.colors.primary, theme.colors.background, 0.8).rgbaString,
            borderWidth: 1,
        },
    });

    useEffect(() => {
        if (!props.isVisible) return;
        pagerView.activePage = props.openPage;
        if (props.infoList.length === 1) {
            setSelectedTeacher(props.infoList[0]);
        }
        pagerView.ref.current?.setPage(props.openPage);
    }, [props.openPage, props.infoList, props.isVisible]);

    return (
        <BottomSheet
            isVisible={props.isVisible}
            onBackdropPress={() => {
                props.onClose?.();
            }}>
            <View style={style.bottomSheetContainer}>
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
                        <TeacherDetailInfo
                            onBack={() => {
                                pagerView.ref.current?.setPage(0);
                            }}
                            name={selectedTeacher?.XM}
                            school={selectedTeacher?.dwmc}
                        />
                    </View>
                </pagerView.AnimatedPagerView>
            </View>
        </BottomSheet>
    );
}

type listProps = {
    onSelect: (teacher: SimpleTeacherInfo) => void;
    list: SimpleTeacherInfo[];
};

function TeacherInfoList(props: listProps) {
    const iconUrl = "https://prof.gxu.edu.cn/images/icon-teacher.jpg";

    const {theme} = useTheme();
    const style = StyleSheet.create({
        press: {
            backgroundColor: Color(theme.colors.primary).setAlpha(0.2).rgbaString,
            width: "100%",
            paddingHorizontal: 12,
            paddingVertical: 8,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: Color(theme.colors.primary).setAlpha(0.6).rgbaString,
        },
    });

    return (
        <View>
            <ScrollView>
                {props.list ? (
                    props.list.map((item, index) => (
                        <View style={{marginTop: 8}}>
                            <UnPressable
                                style={style.press}
                                onPress={() => {
                                    props.onSelect(item);
                                }}>
                                <Flex gap={16} style={{paddingHorizontal: 4}}>
                                    <Image
                                        source={{uri: item.pic ? item.pic : iconUrl}}
                                        style={{width: 60, height: 80, borderRadius: 4}}
                                    />
                                    <View style={{flexDirection: "column", gap: 6, flex: 1}}>
                                        <UnText size={16}>{item.XM}</UnText>
                                        <UnText size={12}>{item.dwmc}</UnText>
                                    </View>
                                </Flex>
                            </UnPressable>
                        </View>
                    ))
                ) : (
                    <UnText size={16}>暂无信息</UnText>
                )}
            </ScrollView>
        </View>
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
    const [activatedIndex, setActivatedIndex] = useState(null);

    const {width: screenWidth, height: screenHeight} = Dimensions.get("window");
    const style = StyleSheet.create({
        sheetContainerStyle: {
            paddingTop: 16,
            paddingHorizontal: 12,
            width: screenWidth,
        },
        baseInfoContainer: {
            flexDirection: "row",
            gap: 16,
            width: screenWidth * 0.9,
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

    async function getDetailInfo() {
        const res = await teacherInfoApi.getDetailInfo(props.name, props.school);
        const info = res.resData;
        setTeacherInfo(info);
    }

    useEffect(() => {
        getDetailInfo();
    }, [props.name, props.school]);

    return (
        <View style={style.sheetContainerStyle}>
            <View>
                <ScrollView>
                    <View style={style.baseInfoContainer}>
                        <Image source={{uri: teacherInfo?.baseInfo.pic || iconUrl}} style={style.image} />
                        <View style={{width: "62%"}}>
                            <View style={style.columContainer}>
                                <View style={{flexDirection: "row", alignItems: "flex-end", gap: 10}}>
                                    <UnText size={22} style={{fontWeight: "bold"}}>
                                        {teacherInfo?.baseInfo.XM}
                                    </UnText>
                                    {teacherInfo?.baseInfo.zhicheng && (
                                        <UnText
                                            size={14}
                                            style={style.eduItem}
                                            color={Color.mix(theme.colors.primary, theme.colors.black, 0.3).rgbaString}>
                                            {teacherInfo?.baseInfo.zhicheng ? teacherInfo?.baseInfo.zhicheng : "无"}
                                        </UnText>
                                    )}
                                    {teacherInfo?.baseInfo.topedu && teacherInfo.baseInfo.ZHXWMC && (
                                        <UnText
                                            size={14}
                                            style={style.eduItem}
                                            color={Color.mix(theme.colors.primary, theme.colors.black, 0.3).rgbaString}>
                                            {teacherInfo?.baseInfo.ZHXWMC} | {teacherInfo?.baseInfo.topedu}
                                        </UnText>
                                    )}
                                </View>
                                <View style={style.rowContainer}>
                                    <UnText size={14}>{teacherInfo?.baseInfo.XBM === "1" ? "男" : "女"}</UnText>
                                    <UnText size={14}>{teacherInfo?.baseInfo.zzmm ?? "暂无政治面貌信息"}</UnText>
                                </View>
                                <View style={{flexDirection: "row", width: "83%"}}>
                                    <UnText size={14}>所在单位：</UnText>
                                    <UnText size={14}>{teacherInfo?.baseInfo.forEditDwmc}</UnText>
                                </View>
                                <View style={style.columContainer}>
                                    <UnText size={14}>邮箱编码：{teacherInfo?.baseInfo.yzbm ?? "无"}</UnText>
                                    <View style={{flexDirection: "row"}}>
                                        <UnText size={14}>邮箱：</UnText>
                                        <UnText size={14}>
                                            {teacherInfo?.baseInfo.email?.trim()
                                                ? teacherInfo?.baseInfo.email?.trim()
                                                : "无"}
                                        </UnText>
                                    </View>
                                </View>
                            </View>
                        </View>
                    </View>
                    <Divider orientation={"horizontal"} />
                    <View style={{marginBottom: 4}}>
                        {dataList.map((item, index) => (
                            <>
                                <View>
                                    <UnText size={20} color={theme.colors.primary}>
                                        {item.label}
                                    </UnText>
                                </View>
                                <CollapsedInfo
                                    key={index}
                                    info={item}
                                    isCollapsed={activatedIndex !== index}
                                    onClick={() => {
                                        setActivatedIndex((pre: number | null) => (pre === index ? null : index));
                                    }}>
                                    <UnText>{item.value?.trim() ? item.value?.trim() : "暂无信息"}</UnText>
                                </CollapsedInfo>
                            </>
                        ))}
                    </View>
                </ScrollView>
            </View>
        </View>
    );
}
