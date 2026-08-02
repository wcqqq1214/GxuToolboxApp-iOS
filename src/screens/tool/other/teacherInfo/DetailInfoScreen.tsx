import {UnText, vh, vw} from "@/components/un-ui";
import {Dimensions, ScrollView, StyleSheet, View} from "react-native";
import {Divider, Image, Tab, useTheme} from "@rneui/themed";
import React, {useEffect, useState} from "react";
import {usePagerView} from "react-native-pager-view";
import {teacherInfoApi} from "@/js/info/teacherInfo.ts";
import {DetailResData} from "@/type/api/teacherInfo/info.ts";
import {Color} from "@/shared/color.ts";

export function DetailInfoScreen({route}) {
    const {teacher} = route.params;

    const [teacherInfo, setTeacherInfo] = useState<DetailResData>();
    const pagerView = usePagerView({pagesAmount: 11});

    const {theme} = useTheme();
    const {width: screenWidth, height: screenHeight} = Dimensions.get("window");
    const style = StyleSheet.create({
        mainContainer: {
            paddingHorizontal: screenWidth * 0.02,
            paddingVertical: screenHeight * 0.01,
        },
        tab: {
            height: "auto",
            marginTop: 8,
            paddingHorizontal: 10,
        },
    });

    async function getDetailInfo() {
        const res = await teacherInfoApi.getDetailInfo(teacher.XM, teacher.dwmc);
        const info = res.resData;
        if (info) {
            setTeacherInfo(info);
        } else {
            getDetailInfo();
        }
    }

    useEffect(() => {
        getDetailInfo();
    }, [teacher]);

    const detailDataList = [
        {
            label: "学历与导师类型",
            render: () => (
                <ScrollView style={style.tab}>
                    <UnText size={16}>
                        学历信息：
                        {teacherInfo?.baseInfo.topedu ? teacherInfo.baseInfo.topedu : "无最高学历信息"} |{" "}
                        {teacherInfo?.baseInfo.ZHXWMC ? teacherInfo?.baseInfo.ZHXWMC : "无最后学位信息"}
                    </UnText>
                    <UnText size={16}>
                        导师类别：
                        {teacherInfo?.baseInfo.dslb ? teacherInfo.baseInfo.dslb : "暂无消息"}
                    </UnText>
                    <Divider />
                </ScrollView>
            ),
        },
        {
            label: "指导学科",
            render: () => (
                <ScrollView style={style.tab}>
                    {teacherInfo?.baseInfo.zdxkChs.length > 0 ? (
                        teacherInfo?.baseInfo.zdxkChs.map(item => (
                            <UnText>
                                门类: {item.category || "无"}，一级学科：{item.xkOne || "无"}，二级学科：
                                {item.xkTwo || "无"}
                            </UnText>
                        ))
                    ) : (
                        <UnText>暂无信息</UnText>
                    )}
                    <Divider />
                </ScrollView>
            ),
        },
        {
            label: "联系方式",
            render: () => (
                <ScrollView style={style.tab}>
                    <UnText size={16}>
                        邮政编码：
                        {teacherInfo?.baseInfo.yzbm ? teacherInfo?.baseInfo.yzbm : "暂无信息"}
                    </UnText>
                    <UnText size={16}>
                        Email：
                        {teacherInfo?.baseInfo.email ? teacherInfo?.baseInfo.email : "暂无信息"}
                    </UnText>
                    <UnText size={16}>
                        联系电话：
                        {teacherInfo?.baseInfo.tel ? teacherInfo?.baseInfo.tel : "暂无信息"}
                    </UnText>
                    <UnText size={16}>QQ：{teacherInfo?.baseInfo.qq ? teacherInfo?.baseInfo.qq : "暂无信息"}</UnText>
                    <UnText size={16}>
                        微信：
                        {teacherInfo?.baseInfo.weixin ? teacherInfo?.baseInfo.weixin : "暂无信息"}
                    </UnText>

                    <Divider />
                </ScrollView>
            ),
        },
        {
            label: "个人简介",
            render: () => (
                <ScrollView style={style.tab}>
                    <UnText size={16}>
                        {teacherInfo?.largeMsg.zyxxjx ? teacherInfo?.largeMsg.zyxxjx : "暂无信息"}
                    </UnText>
                    <Divider />
                </ScrollView>
            ),
        },
        {
            label: "主讲课程",
            render: () => (
                <ScrollView style={style.tab}>
                    <UnText size={16}>{teacherInfo?.largeMsg.zyyjskc || "暂无信息"}</UnText>
                    <Divider />
                </ScrollView>
            ),
        },
        {
            label: "主持（参与）的主要科研项目",
            render: () => (
                <ScrollView style={style.tab}>
                    <UnText size={16}>{teacherInfo?.largeMsg.zckyxm || "暂无信息"}</UnText>
                    <Divider />
                </ScrollView>
            ),
        },
        {
            label: "主要研究方向",
            render: () => (
                <ScrollView style={style.tab}>
                    <UnText size={16}>{teacherInfo?.largeMsg.zyyjfx || "暂无信息"}</UnText>
                    <Divider />
                </ScrollView>
            ),
        },
        {
            label: "取得的主要成果",
            render: () => (
                <ScrollView style={style.tab}>
                    <UnText size={16}>
                        {[teacherInfo?.largeMsg?.lw, teacherInfo?.largeMsg?.zz, teacherInfo?.largeMsg?.zl]
                            .filter(Boolean)
                            .join("\n") || "暂无信息"}
                    </UnText>
                    <Divider />
                </ScrollView>
            ),
        },
        {
            label: "荣誉与获奖",
            render: () => (
                <ScrollView style={style.tab}>
                    <UnText size={16}>{teacherInfo?.largeMsg.ryyhj || "暂无信息"}</UnText>
                    <Divider />
                </ScrollView>
            ),
        },
        {
            label: "招生信息",
            render: () => (
                <ScrollView style={style.tab}>
                    <UnText size={16}>{teacherInfo?.largeMsg.zsxx || "暂无信息"}</UnText>
                    <Divider />
                </ScrollView>
            ),
        },
        {
            label: "学术兼职",
            render: () => (
                <ScrollView style={style.tab}>
                    <UnText size={16}>{teacherInfo?.largeMsg.xsjz || "暂无信息"}</UnText>
                    <Divider />
                </ScrollView>
            ),
        },
    ];

    return (
        <>
            <ScrollView style={style.mainContainer}>
                <BaseInfoItem item={teacherInfo} />

                <Divider />

                <ScrollView horizontal={true}>
                    <Tab
                        value={pagerView.activePage}
                        onChange={i => pagerView.ref.current?.setPage(i)}
                        variant="default"
                        dense
                        titleStyle={{color: theme.colors.primary}}
                        animationType="timing"
                        indicatorStyle={{backgroundColor: theme.colors.primary}}>
                        {detailDataList.map(item => (
                            <Tab.Item title={item.label} />
                        ))}
                    </Tab>
                </ScrollView>

                <pagerView.AnimatedPagerView
                    ref={pagerView.ref}
                    style={{width: "100%", height: vh(53)}}
                    overScrollMode="never"
                    orientation="horizontal"
                    onPageSelected={pagerView.onPageSelected}>
                    {detailDataList.map((item, index) => (
                        <View key={index} collapsable={false} style={{width: "100%", height: vh(53)}}>
                            {item.render()}
                        </View>
                    ))}
                </pagerView.AnimatedPagerView>
            </ScrollView>
        </>
    );
}

type BaseItemProps = {
    item: DetailResData;
};

export function BaseInfoItem(props: BaseItemProps) {
    const iconUrl = "https://prof.gxu.edu.cn/images/icon-teacher.jpg";

    const {theme} = useTheme();
    const style = StyleSheet.create({
        baseInfo: {
            flexDirection: "row",
            alignItems: "center",
            width: vw(96),
            paddingLeft: 10,
            gap: 20
        },
        baseInfoItem: {
            marginTop: 6
        },
        eduItem: {
            backgroundColor: Color(theme.colors.primary).setAlpha(0.3).rgbaString,
            paddingHorizontal: 4,
            padding: 2,
            borderRadius: 4,
        },
    });

    return (
        <View>
            <View style={style.baseInfo}>
                <Image
                    source={{uri: props.item?.baseInfo.pic || iconUrl}}
                    style={{width: 110, height: 150, borderRadius: 4}}
                />

                <ScrollView contentContainerStyle={{width: "92%"}} style={{height: 150}}>
                    <View style={{flexDirection: "row", alignItems: "center", gap: 10}}>
                        <UnText size={20} style={{fontWeight: "bold", color: theme.colors.primary}}>
                            {props.item?.baseInfo.XM}
                        </UnText>
                        <View style={{flexDirection: "row", gap: 4}}>
                            <UnText
                                size={14}
                                style={style.eduItem}
                                color={Color.mix(theme.colors.primary, theme.colors.black, 0.3).rgbaString}>
                                {props.item?.baseInfo.zhicheng ? props.item?.baseInfo.zhicheng : "无职称信息"}
                            </UnText>
                        </View>
                    </View>
                    <View style={{flexDirection: "row", marginBottom: 2, gap: 4}}>
                        <UnText size={14}>{props.item?.baseInfo.XBM === "1" ? "男" : "女"}</UnText>
                        <UnText size={14}>{props.item?.baseInfo.zzmm ?? "暂无政治面貌信息"}</UnText>
                    </View>
                    <View style={style.baseInfoItem}>
                        <UnText size={14}>所在单位：</UnText>
                        <UnText size={14}>
                            {props.item?.baseInfo.forEditDwmc ? props.item.baseInfo.forEditDwmc : "暂无信息"}
                        </UnText>
                    </View>
                    <View style={style.baseInfoItem}>
                        <UnText size={14}>通讯地址：</UnText>
                        <UnText size={14}>
                            {props.item?.baseInfo.address ? props.item.baseInfo.address : "暂无信息"}
                        </UnText>
                    </View>
                </ScrollView>
            </View>
        </View>
    );
}
